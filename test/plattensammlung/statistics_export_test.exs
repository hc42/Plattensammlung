defmodule Plattensammlung.StatisticsExportTest do
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Export

  setup do
    user = user_fixture()

    Records.add_to_collection!(
      "The Beatles",
      "Abbey Road",
      %{
        year: 1969,
        genres: ["Rock", "Pop"],
        discogs_master_id: 24047,
        copy: %{
          label: "Apple Records",
          catalog_number: "PCS 7088",
          barcode: "0602547288530",
          media_condition: :very_good_plus,
          notes: "Erbstück, \"Original\""
        }
      },
      actor: user
    )

    abbey = Records.find_duplicates!("The Beatles", "Abbey Road", actor: user) |> hd()

    Records.add_copy!(abbey.id, %{media_condition: :good}, actor: user)

    Records.add_to_collection!("The Beatles", "Revolver", %{year: 1966, genres: ["Rock"]},
      actor: user
    )

    Records.add_to_collection!("Miles Davis", "Kind of Blue", %{year: 1959, genres: ["Jazz"]},
      actor: user
    )

    Records.add_to_wishlist!("Can", "Tago Mago", %{year: 1971}, actor: user)

    %{user: user}
  end

  describe "statistics" do
    test "counts with database aggregates", %{user: user} do
      stats = Records.statistics!(actor: user)

      assert stats.albums == 3
      assert stats.copies == 4
      assert stats.wishlist == 1
      assert stats.artists == 2
    end

    test "breaks the collection down", %{user: user} do
      stats = Records.statistics!(actor: user)

      assert stats.genres == [
               %{label: "Rock", count: 2},
               %{label: "Jazz", count: 1},
               %{label: "Pop", count: 1}
             ]

      assert stats.decades == [%{label: "1950er", count: 1}, %{label: "1960er", count: 2}]

      assert [%{label: "The Beatles", count: 2}, %{label: "Miles Davis", count: 1}] =
               stats.top_artists

      # Goldmine order, best first; copies without a grade last
      assert Enum.map(stats.conditions, & &1.label) ==
               ["Very Good Plus (VG+)", "Good (G)", "Ohne Angabe"]
    end

    test "needs a signed-in user" do
      assert {:error, %Ash.Error.Forbidden{}} = Records.statistics()
    end
  end

  describe "CSV export" do
    test "has a row per copy and per wishlist album", %{user: user} do
      [header | rows] = user |> csv_rows()

      assert hd(header) == "status"
      assert length(rows) == 5
      assert Enum.count(rows, &(hd(&1) == "wishlist")) == 1

      row =
        Enum.find(rows, &(Enum.at(&1, 7) == "PCS 7088"))
        |> then(&Enum.zip(header, &1))
        |> Map.new()

      assert row["artist"] == "The Beatles"
      assert row["genres"] == "Rock; Pop"
      assert row["media_condition"] == "VG+"
      # Quotes and commas survive the round trip
      assert row["notes"] == "Erbstück, \"Original\""
    end

    defp csv_rows(user) do
      [actor: user] |> Export.csv() |> Export.CSV.parse_string(skip_headers: false)
    end
  end

  describe "JSON-LD export" do
    test "describes owned albums with schema.org, without private details", %{user: user} do
      json_ld = Export.json_ld([actor: user], "https://mac.local:4001")

      assert json_ld["@context"] == "https://schema.org"
      assert json_ld["@type"] == "ItemList"
      assert json_ld["numberOfItems"] == 3

      album =
        json_ld["itemListElement"]
        |> Enum.map(& &1["item"])
        |> Enum.find(&(&1["name"] == "Abbey Road"))

      assert album["@type"] == "MusicAlbum"
      assert album["byArtist"] == %{"@type" => "MusicGroup", "name" => "The Beatles"}
      assert album["datePublished"] == "1969"
      assert album["sameAs"] == ["https://www.discogs.com/master/24047"]

      assert [release | _] = album["albumRelease"]
      assert release["@type"] == "MusicRelease"
      assert release["musicReleaseFormat"] == "https://schema.org/VinylFormat"

      encoded = Phoenix.json_library().encode!(json_ld)
      refute encoded =~ "Erbstück"
      refute encoded =~ "Tago Mago"
    end
  end
end
