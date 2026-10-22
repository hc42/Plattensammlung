defmodule PlattensammlungWeb.AlbumComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias PlattensammlungWeb.AlbumComponents

  defp placeholder(title) do
    html = render_component(&AlbumComponents.cover/1, album: %{title: title, cover_url: nil})
    [_, initials] = Regex.run(~r/tracking-tight">\s*([^<]*?)\s*</, html)
    initials
  end

  test "placeholders show the initials of the title" do
    assert placeholder("Kind of Blue") == "KB"
    assert placeholder("Trans Europa Express") == "TE"
    assert placeholder("Tago Mago") == "TM"
    assert placeholder("Help!") == "H"
    assert placeholder("1999") == "1"
    assert placeholder("Ça plane pour moi") == "ÇP"
  end

  test "every album keeps its own label colour" do
    assert AlbumComponents.label_style(%{title: "Tago Mago"}) ==
             AlbumComponents.label_style(%{title: "Tago Mago"})

    refute AlbumComponents.label_style(%{title: "Tago Mago"}) ==
             AlbumComponents.label_style(%{title: "Kind of Blue"})
  end

  test "an album with a cover shows no initials" do
    html =
      render_component(&AlbumComponents.cover/1,
        album: %{title: "Tago Mago", cover_url: "/covers/a.jpg"}
      )

    refute html =~ "TM"
    assert html =~ "delayed-fade-in"
  end
end
