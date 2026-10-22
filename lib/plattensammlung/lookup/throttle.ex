defmodule Plattensammlung.Lookup.Throttle do
  @moduledoc """
  Spaces out requests to an external service: `wait(key, interval_ms)` returns
  once at least `interval_ms` have passed since the previous request with the
  same key, across all processes of this node. Used for MusicBrainz, which
  allows about one request per second (ADR 0017).

  The server only hands out time slots; callers sleep in their own process.
  """
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Blocks the caller until its slot for `key` has come."
  def wait(_key, interval_ms) when interval_ms <= 0, do: :ok

  def wait(key, interval_ms) do
    case GenServer.call(__MODULE__, {:slot, key, interval_ms}) do
      0 -> :ok
      delay -> Process.sleep(delay)
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:slot, key, interval_ms}, _from, next_free) do
    now = System.monotonic_time(:millisecond)
    slot = max(now, Map.get(next_free, key, now))
    {:reply, slot - now, Map.put(next_free, key, slot + interval_ms)}
  end
end
