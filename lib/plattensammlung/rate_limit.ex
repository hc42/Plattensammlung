defmodule Plattensammlung.RateLimit do
  @moduledoc """
  In-memory rate limits (Hammer with an ETS table, ADR 0017). Enough for one
  app instance; counters start fresh after a restart.

      Plattensammlung.RateLimit.hit("key", :timer.minutes(15), 3)
      #=> {:allow, count} | {:deny, retry_after_ms}
  """
  use Hammer, backend: :ets
end
