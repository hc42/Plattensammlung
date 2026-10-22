defmodule Plattensammlung.InputLimitsTest do
  @moduledoc "Length and value limits of the record fields (ADR 0006, Nachtrag)."
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records

  setup do
    user = user_fixture()
    album = Records.add_to_collection!("Can", "Tago Mago", actor: user)
    [copy] = Ash.load!(album, :copies, authorize?: false).copies
    %{user: user, album: album, copy: copy}
  end

  test "album texts and lists have limits", %{user: user} do
    long = String.duplicate("a", 201)

    assert {:error, %Ash.Error.Invalid{}} = Records.add_to_wishlist(long, "B", actor: user)
    assert {:error, %Ash.Error.Invalid{}} = Records.add_to_wishlist("A", long, actor: user)

    for genres <- [List.duplicate("Rock", 21), [String.duplicate("g", 51)]] do
      assert {:error, %Ash.Error.Invalid{}} =
               Records.add_to_wishlist("A", "B", %{genres: genres}, actor: user)
    end

    assert {:error, %Ash.Error.Invalid{}} =
             Records.add_to_wishlist("A", "B", %{discogs_master_id: -5}, actor: user)

    # Emojis are fine and count as code points, like in Postgres
    assert {:ok, album} = Records.add_to_wishlist("A", String.duplicate("🎵", 200), actor: user)
    assert album.title |> to_string() |> String.length() == 200
  end

  test "copy fields have limits", %{copy: copy, user: user} do
    for attrs <- [
          %{notes: String.duplicate("n", 2001)},
          %{label: String.duplicate("l", 101)},
          %{pressing_year: -5},
          %{discogs_release_id: 0},
          %{format: List.duplicate("LP", 21)}
        ] do
      assert {:error, %Ash.Error.Invalid{}} = Records.update_copy(copy, attrs, actor: user),
             inspect(attrs)
    end

    assert {:ok, _} =
             Records.update_copy(copy, %{notes: String.duplicate("n", 2000)}, actor: user)
  end

  test "barcodes are normalized and must be 8 to 14 digits", %{copy: copy, user: user} do
    assert {:ok, %{barcode: "5099902987620"}} =
             Records.update_copy(copy, %{barcode: " 5 099902-987620 "}, actor: user)

    for barcode <- ["123", "<script>", "509990298762012345"] do
      assert {:error, %Ash.Error.Invalid{}} =
               Records.update_copy(copy, %{barcode: barcode}, actor: user)
    end

    assert {:ok, %{barcode: nil}} = Records.update_copy(copy, %{barcode: nil}, actor: user)
  end

  test "search arguments are limited, odd decades are ignored", %{user: user} do
    assert {:error, %Ash.Error.Invalid{}} =
             Records.search_albums(String.duplicate("q", 201), nil, actor: user)

    assert [_] =
             Records.search_albums!(nil, nil, %{decade: "99999999999999999999"}, actor: user)

    assert {:error, %Ash.Error.Invalid{}} =
             Records.lookup_albums(String.duplicate("q", 201), actor: user)
  end
end
