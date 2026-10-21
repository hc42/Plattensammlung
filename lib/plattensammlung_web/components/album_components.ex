defmodule PlattensammlungWeb.AlbumComponents do
  @moduledoc """
  UI building blocks for albums and copies.
  """
  use Phoenix.Component

  import PlattensammlungWeb.CoreComponents, only: [icon: 1]

  alias Plattensammlung.Records.Condition

  @doc """
  Square album cover; falls back to a stylised record when there is no image.
  """
  attr :album, :map, required: true
  attr :class, :any, default: nil

  def cover(assigns) do
    ~H"""
    <div class={[
      "relative aspect-square overflow-hidden rounded-lg bg-base-300 shadow-sm",
      @class
    ]}>
      <img
        :if={@album.cover_url}
        src={@album.cover_url}
        alt={"Cover: #{@album.title}"}
        loading="lazy"
        class="size-full object-cover"
      />
      <div :if={!@album.cover_url} class="grid size-full place-items-center">
        <div class="grid aspect-square w-3/4 place-items-center rounded-full bg-neutral shadow-inner">
          <div class="grid aspect-square w-1/3 place-items-center rounded-full bg-primary/70">
            <div class="size-1.5 rounded-full bg-base-100"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Shows whether an album is owned (with number of copies) or on the wishlist.
  Expects the `owned` and `copy_count` aggregates to be loaded.
  """
  attr :album, :map, required: true

  def status_badge(assigns) do
    ~H"""
    <span :if={@album.owned and @album.copy_count > 1} class="badge badge-sm badge-neutral">
      {@album.copy_count}×
    </span>
    <span :if={@album.wanted} class="badge badge-sm badge-accent gap-1">
      <.icon name="hero-heart-micro" class="size-3" /> Wunschliste
    </span>
    """
  end

  @doc "Select options for the Goldmine grading scale."
  def condition_options do
    Enum.map(Condition.values(), &{Condition.description(&1), &1})
  end

  @doc "Short label for a condition, e.g. \"VG+\"."
  def condition_label(nil), do: nil

  def condition_label(condition) do
    case Regex.run(~r/\(([^)]+)\)/, Condition.description(condition)) do
      [_, short] -> short
      _ -> to_string(condition)
    end
  end
end
