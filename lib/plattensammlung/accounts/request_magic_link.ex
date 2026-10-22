defmodule Plattensammlung.Accounts.RequestMagicLink do
  @moduledoc """
  Runs AshAuthentication's magic link request, limited (ADR 0017):

  * per address – so no one can flood a mailbox or get the app's SMTP account
    throttled,
  * per client IP, if the caller passes `client_ip` in the action context
    (the sign-in page does).

  Over the limit nothing is sent, but the answer stays the same, so the page
  still doesn't reveal anything about the address.
  """
  use Ash.Resource.Actions.Implementation

  alias AshAuthentication.Strategy.MagicLink.Request
  alias Plattensammlung.RateLimit

  require Logger

  @impl true
  def run(input, opts, context) do
    email = input.arguments.email |> to_string() |> String.downcase()

    if allowed?("email:#{email}", :per_address) and
         allowed?(input.context[:client_ip] && "ip:#{input.context[:client_ip]}", :per_ip) do
      Request.run(input, opts, context)
    else
      Logger.warning("Magic link request over the rate limit")
      :ok
    end
  end

  defp allowed?(nil, _limit), do: true

  defp allowed?(key, limit) do
    {count, scale_ms} = Application.fetch_env!(:plattensammlung, :magic_link_limits)[limit]
    match?({:allow, _count}, RateLimit.hit("magic_link:" <> key, scale_ms, count))
  end
end
