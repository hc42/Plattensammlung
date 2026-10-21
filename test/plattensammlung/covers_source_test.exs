defmodule Plattensammlung.CoversSourceTest do
  use ExUnit.Case, async: true

  alias Plattensammlung.Covers

  test "only https URLs on the cover hosts are allowed" do
    assert Covers.allowed_url?("https://i.discogs.com/a.jpg")
    assert Covers.allowed_url?("https://ia800.us.archive.org/a.jpg")
    refute Covers.allowed_url?("http://i.discogs.com/a.jpg")
    refute Covers.allowed_url?("https://192.168.1.1/a.jpg")
    refute Covers.allowed_url?("https://evil-archive.org/a.jpg")
    refute Covers.allowed_url?("/covers/x.jpg")
  end

  test "covers from other hosts are not downloaded" do
    assert {:error, :host_not_allowed} = Covers.store("https://nas.local/admin.png")
  end
end
