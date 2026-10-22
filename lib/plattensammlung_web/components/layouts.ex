defmodule PlattensammlungWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PlattensammlungWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :current_user, :map, default: nil, doc: "the signed-in user; the menu is hidden without"
  attr :current_path, :string, default: nil, doc: "marks the active page in the navigation"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-20 border-b border-base-300 bg-base-100/90 backdrop-blur">
      <nav class="mx-auto flex max-w-5xl items-center gap-1 px-4 py-3 sm:gap-2 sm:px-6">
        <.link navigate={~p"/"} class="mr-auto flex items-center gap-2.5 font-semibold">
          <span class="grid size-8 place-items-center rounded-full bg-neutral shadow-sm">
            <span class="grid size-3.5 place-items-center rounded-full bg-primary">
              <span class="size-1 rounded-full bg-base-100"></span>
            </span>
          </span>
          <span class="font-display text-lg tracking-tight">Plattensammlung</span>
        </.link>
        <%= if @current_user do %>
          <.nav_link
            navigate={~p"/"}
            active={@current_path == ~p"/"}
            id="nav-collection"
            class="hidden sm:inline-flex"
          >
            {gettext("Collection")}
          </.nav_link>
          <.nav_link
            navigate={~p"/wishlist"}
            active={@current_path == ~p"/wishlist"}
            id="nav-wishlist"
            class="hidden sm:inline-flex"
          >
            {gettext("Wishlist")}
          </.nav_link>
          <.link
            navigate={~p"/import"}
            class="btn btn-primary btn-sm hidden sm:inline-flex"
            id="nav-new"
          >
            <.icon name="hero-plus" class="size-4" /> {pgettext("navigation", "Add")}
          </.link>
          <.nav_link
            navigate={~p"/collectors"}
            active={active?(@current_path, ~p"/collectors")}
            id="nav-collectors"
            class="btn-square"
            label={gettext("Collectors")}
          >
            <.icon name="hero-users" class="size-5" />
          </.nav_link>
          <.nav_link
            navigate={~p"/stats"}
            active={@current_path == ~p"/stats"}
            id="nav-stats"
            class="btn-square hidden sm:inline-flex"
            label={gettext("Statistics")}
          >
            <.icon name="hero-chart-bar" class="size-5" />
          </.nav_link>
          <.nav_link
            navigate={~p"/account"}
            active={@current_path == ~p"/account"}
            id="nav-account"
            class="btn-square hidden sm:inline-flex"
            label={gettext("Account")}
          >
            <.icon name="hero-user-circle" class="size-5" />
          </.nav_link>
        <% end %>
        <div class="ml-1"><.theme_toggle /></div>
      </nav>
    </header>

    <%!-- overflow-x-clip: records sliding out of their sleeve must not widen the page --%>
    <main class={[
      "overflow-x-clip px-4 pt-6 sm:px-6 sm:pt-10",
      if(@current_user, do: "pb-28 sm:pb-12", else: "pb-12")
    ]}>
      <div class="mx-auto max-w-5xl space-y-8">
        {render_slot(@inner_block)}
      </div>
    </main>

    <%!-- Phones: the main pages at the bottom, within reach of the thumb, with the scanner in the middle --%>
    <nav
      :if={@current_user}
      id="bottom-nav"
      class="fixed inset-x-0 bottom-0 z-20 border-t border-base-300 bg-base-100/95 pb-[env(safe-area-inset-bottom)] backdrop-blur sm:hidden"
      aria-label={gettext("Main navigation")}
    >
      <div class="grid h-16 grid-cols-5 items-center">
        <.tab_link
          navigate={~p"/"}
          active={@current_path == ~p"/"}
          icon="hero-squares-2x2"
          active_icon="hero-squares-2x2-solid"
          id="tab-collection"
        >
          {gettext("Collection")}
        </.tab_link>
        <.tab_link
          navigate={~p"/wishlist"}
          active={@current_path == ~p"/wishlist"}
          icon="hero-heart"
          active_icon="hero-heart-solid"
          id="tab-wishlist"
        >
          {gettext("Wishlist")}
        </.tab_link>
        <.link
          navigate={~p"/import?scan=1"}
          id="tab-scan"
          class="mx-auto -mt-7 grid size-16 place-items-center rounded-full bg-primary text-primary-content shadow-lg ring-4 ring-base-100 transition active:scale-95"
          aria-label={gettext("Scan a barcode")}
        >
          <.icon name="hero-camera" class="size-7" />
        </.link>
        <.tab_link
          navigate={~p"/stats"}
          active={@current_path == ~p"/stats"}
          icon="hero-chart-bar"
          active_icon="hero-chart-bar-solid"
          id="tab-stats"
        >
          {gettext("Statistics")}
        </.tab_link>
        <.tab_link
          navigate={~p"/account"}
          active={@current_path == ~p"/account"}
          icon="hero-user-circle"
          active_icon="hero-user-circle-solid"
          id="tab-account"
        >
          {gettext("Account")}
        </.tab_link>
      </div>
    </nav>

    <.flash_group flash={@flash} />
    """
  end

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :label, :string, default: nil, doc: "aria-label for icon-only links"
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      id={@id}
      class={["btn btn-ghost btn-sm", @active && "bg-base-200 text-primary", @class]}
      aria-current={@active && "page"}
      aria-label={@label}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  # Literal names: Tailwind only generates icon classes it finds in the source
  attr :active_icon, :string, required: true
  attr :id, :string, required: true
  slot :inner_block, required: true

  defp tab_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      id={@id}
      class={[
        "flex flex-col items-center gap-0.5 text-[0.6875rem] font-medium",
        if(@active, do: "text-primary", else: "opacity-70")
      ]}
      aria-current={@active && "page"}
    >
      <.icon name={if @active, do: @active_icon, else: @icon} class="size-6" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  # Active for the page and the pages below it, e.g. /collectors/…
  defp active?(nil, _path), do: false
  defp active?(current, path), do: current == path or String.starts_with?(current, path <> "/")

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
