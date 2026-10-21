defmodule Plattensammlung.AccountsFixtures do
  @moduledoc """
  Test users. `test@example.com` is in the test config's `allowed_emails`.
  """

  def user_fixture(email \\ "test@example.com") do
    Ash.Seed.seed!(Plattensammlung.Accounts.User, %{email: email})
  end

  @doc "Returns `{plaintext_key, api_key}` for the user."
  def api_key_fixture(user, expires_at \\ DateTime.add(DateTime.utc_now(), 30, :day)) do
    api_key = Plattensammlung.Accounts.create_api_key!(expires_at, actor: user)
    {api_key.__metadata__.plaintext_api_key, api_key}
  end
end
