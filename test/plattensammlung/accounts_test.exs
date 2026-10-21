defmodule Plattensammlung.AccountsTest do
  # Not async: tests change the global allowed_emails config
  use Plattensammlung.DataCase, async: false

  import Swoosh.TestAssertions

  alias Plattensammlung.Accounts
  alias Plattensammlung.Accounts.User

  @moduletag :capture_log

  describe "magic link" do
    test "is mailed to an allowed address, pointing to the given host" do
      :ok =
        Accounts.request_magic_link("Test@Example.com",
          context: %{base_url: "https://mac.local:4001"}
        )

      assert_email_sent(fn email ->
        assert [{_, "Test@Example.com"}] = email.to
        assert email.html_body =~ "https://mac.local:4001/magic_link/"
      end)
    end

    test "is not mailed to other addresses, without revealing it" do
      assert :ok = Accounts.request_magic_link("stranger@example.com")
      assert_no_email_sent()
    end

    test "a failing mail server is logged, not raised" do
      mailer_config = Application.get_env(:plattensammlung, Plattensammlung.Mailer)

      Application.put_env(:plattensammlung, Plattensammlung.Mailer,
        adapter: __MODULE__.FailingAdapter
      )

      on_exit(fn ->
        Application.put_env(:plattensammlung, Plattensammlung.Mailer, mailer_config)
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert :ok = Accounts.request_magic_link("test@example.com")
        end)

      assert log =~ "could not be sent"
    end

    test "signs in an allowed address and creates the user" do
      assert {:ok, %User{} = user} = sign_in_with_token_for("test@example.com")
      assert to_string(user.email) == "test@example.com"
    end

    test "refuses a valid token for an address that is not allowed" do
      assert {:error, %AshAuthentication.Errors.AuthenticationFailed{}} =
               sign_in_with_token_for("stranger@example.com")

      assert Ash.read!(User, authorize?: false) == []
    end
  end

  describe "API keys" do
    test "belong to the user who creates them" do
      alice = user_fixture()
      bob = user_fixture("bob@example.com")
      {_plain, key} = api_key_fixture(alice)

      assert [%{id: id}] = Accounts.list_api_keys!(actor: alice)
      assert id == key.id
      assert Accounts.list_api_keys!(actor: bob) == []
      assert {:error, %Ash.Error.Forbidden{}} = Accounts.destroy_api_key(key, actor: bob)
    end
  end

  test "passkeys are only visible to their owner" do
    alice = user_fixture()
    bob = user_fixture("bob@example.com")

    Accounts.register_passkey!(
      %{name: "Alice", credential_id: "id", public_key: "key", sign_count: 0},
      actor: alice
    )

    assert [%{name: "Alice"}] = Accounts.list_passkeys!(actor: alice)
    assert Accounts.list_passkeys!(actor: bob) == []
  end

  # Creates a magic link token like the request action does, then signs in with it
  defp sign_in_with_token_for(email) do
    strategy = AshAuthentication.Info.strategy!(User, :magic_link)

    {:ok, token} =
      AshAuthentication.Strategy.MagicLink.request_token_for_identity(strategy, email, [], %{})

    AshAuthentication.Strategy.action(strategy, :sign_in, %{"token" => token})
  end

  defmodule FailingAdapter do
    @moduledoc false
    use Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, :smtp_unreachable}
  end
end
