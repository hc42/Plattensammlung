defmodule Plattensammlung.SortAlbumsTest do
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records

  setup do
    alice = user_fixture()
    bob = user_fixture("bob@example.com")

    # Bob brought Trans Europa Express into the catalog first, Alice adds it last
    Records.add_to_collection!("Harmonia", "Trans Europa Express", %{year: 1977}, actor: bob)
    Records.add_to_collection!("Moebius", "Kind of Blue", %{year: 1959}, actor: alice)
    Records.add_to_collection!("Cluster", "Tago Mago", %{year: 1971}, actor: alice)
    Records.add_to_collection!("Cluster", "Ege Bamyasi", actor: alice)
    Records.add_to_collection!("Harmonia", "Trans Europa Express", actor: alice)

    %{alice: alice}
  end

  defp titles(sort, alice) do
    nil
    |> Records.search_albums!(:collection, %{order: sort}, actor: alice)
    |> Enum.map(&to_string(&1.title))
  end

  test "sorts by title by default", %{alice: alice} do
    assert titles(nil, alice) ==
             ["Ege Bamyasi", "Kind of Blue", "Tago Mago", "Trans Europa Express"]
  end

  test "sorts by artist, then year", %{alice: alice} do
    assert titles(:artist, alice) ==
             ["Tago Mago", "Ege Bamyasi", "Trans Europa Express", "Kind of Blue"]
  end

  test "sorts by year, albums without year last", %{alice: alice} do
    assert titles(:year, alice) ==
             ["Kind of Blue", "Tago Mago", "Trans Europa Express", "Ege Bamyasi"]
  end

  test "sorts by when the user added the album, newest first", %{alice: alice} do
    assert titles(:added, alice) ==
             ["Trans Europa Express", "Ege Bamyasi", "Tago Mago", "Kind of Blue"]
  end
end
