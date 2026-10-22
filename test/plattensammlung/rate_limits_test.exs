defmodule Plattensammlung.RateLimitsTest do
  @moduledoc "Rate limits of magic links and the MusicBrainz throttle (ADR 0017)."
  # Not async: changes the global limit config
  use Plattensammlung.DataCase, async: false

  import Swoosh.TestAssertions

  alias Plattensammlung.Accounts
  alias Plattensammlung.Lookup.Throttle

  @moduletag :capture_log

  setup do
    limits = Application.fetch_env!(:plattensammlung, :magic_link_limits)
    allowed = Application.fetch_env!(:plattensammlung, :allowed_emails)

    on_exit(fn ->
      Application.put_env(:plattensammlung, :magic_link_limits, limits)
      Application.put_env(:plattensammlung, :allowed_emails, allowed)
    end)

    # The counters live in ETS across tests: a fresh allowed address per test
    email = "limit-#{System.unique_integer([:positive])}@example.com"
    Application.put_env(:plattensammlung, :allowed_emails, [email])

    Application.put_env(:plattensammlung, :magic_link_limits,
      per_address: {2, :timer.minutes(15)},
      per_ip: {3, :timer.hours(1)}
    )

    %{email: email, ip: "203.0.113.#{System.unique_integer([:positive]) |> rem(250)}"}
  end

  test "an address gets only a few links, the answer stays the same", %{email: email} do
    # Mixed case counts as the same address
    for address <- [email, String.upcase(email), email] do
      assert :ok = Accounts.request_magic_link(address, context: %{client_ip: unique_ip()})
    end

    assert_email_sent()
    assert_email_sent()
    assert_no_email_sent()
  end

  test "one IP can't try many addresses", %{email: email, ip: ip} do
    for email <- ["a@example.com", "b@example.com", "c@example.com"] do
      Accounts.request_magic_link(email, context: %{client_ip: ip})
    end

    # Fourth request from the same IP: refused before even looking at the address
    Accounts.request_magic_link(email, context: %{client_ip: ip})
    assert_no_email_sent()
  end

  test "the throttle spaces out requests" do
    key = {:test, make_ref()}
    started = System.monotonic_time(:millisecond)

    1..3
    |> Enum.map(fn _ -> Task.async(fn -> Throttle.wait(key, 50) end) end)
    |> Enum.each(&Task.await/1)

    assert System.monotonic_time(:millisecond) - started >= 100
  end

  # Avoids leftovers of the address counter from other tests
  defp unique_ip, do: "198.51.100.#{System.unique_integer([:positive]) |> rem(250)}"
end
