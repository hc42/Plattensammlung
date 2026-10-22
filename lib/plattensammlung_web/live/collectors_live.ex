defmodule PlattensammlungWeb.CollectorsLive do
  @moduledoc """
  The other users of the app with their collection and wishlist (ADR 0013).
  Every signed-in user may look at every collection and wishlist (ADR 0013, 0016).
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.{Accounts, Records}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <h1 class="text-2xl font-bold">Sammler</h1>
        <p class="text-sm opacity-70">
          Die Sammlungen und Wunschlisten der anderen. Ändern kann sie nur ihr Besitzer.
        </p>
      </div>

      <p :if={@collectors == []} class="py-8 opacity-70" id="no-collectors">
        Noch keine anderen Sammler.
      </p>

      <ul id="collectors" class="divide-y divide-base-300 rounded-lg border border-base-300">
        <li
          :for={collector <- @collectors}
          id={"collector-#{collector.user.id}"}
          class="flex flex-wrap items-center gap-3 p-4"
        >
          <.icon name="hero-user-circle" class="size-8 opacity-60" />
          <p class="flex-1 font-medium">{Accounts.display_name(collector.user)}</p>
          <.link navigate={~p"/collectors/#{collector.user.id}"} class="btn btn-sm">
            Sammlung · {collector.stats.albums}
          </.link>
          <.link navigate={~p"/collectors/#{collector.user.id}/wishlist"} class="btn btn-sm btn-ghost">
            Wunschliste · {collector.stats.wishlist}
          </.link>
        </li>
      </ul>

      <p :if={!@current_user.display_name} class="text-sm opacity-70" id="name-hint">
        Tipp: Unter <.link navigate={~p"/account"} class="link">Konto</.link>
        legst du fest, unter welchem Namen dich die anderen sehen.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    collectors =
      Accounts.list_collectors!(actor: actor)
      |> Enum.reject(&(&1.id == actor.id))
      |> Enum.map(fn user ->
        %{user: user, stats: Records.statistics!(%{owner_id: user.id}, actor: actor)}
      end)

    {:ok, socket |> assign(:page_title, "Sammler") |> assign(:collectors, collectors)}
  end
end
