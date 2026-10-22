# Example data for development. Run with:
#
#     ALLOWED_EMAILS=du@example.de mix run priv/repo/seeds.exs
#
# Collection and wishlist of the first address in ALLOWED_EMAILS (the user is
# created if needed). Safe to run repeatedly: albums that user already has are skipped.
# Seeds run without a signed-in user, so authorization is skipped explicitly.
alias Plattensammlung.Accounts.User
alias Plattensammlung.Records

require Ash.Query

case Application.get_env(:plattensammlung, :allowed_emails, []) do
  [] ->
    IO.puts(
      "Seeds übersprungen: ALLOWED_EMAILS ist leer, es gibt niemanden, dem die Alben gehören."
    )

  [email | _] ->
    owner =
      case User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false) do
        nil -> Ash.Seed.seed!(User, %{email: email})
        user -> user
      end

    opts = [actor: owner, authorize?: false]

    existing =
      (Records.list_collection!(opts) ++ Records.list_wishlist!(opts))
      |> MapSet.new(&{to_string(&1.artist.name), to_string(&1.title)})

    collection = [
      {"The Beatles", "Abbey Road",
       %{
         year: 1969,
         genres: ["Rock", "Pop"],
         discogs_master_id: 24047,
         copy: %{
           label: "Apple Records",
           catalog_number: "PCS 7088",
           country: "UK",
           format: ["LP"],
           media_condition: :very_good_plus,
           sleeve_condition: :very_good,
           purchased_on: ~D[2019-05-03]
         }
       }},
      {"Pink Floyd", "The Dark Side of the Moon", %{year: 1973, genres: ["Rock"]}},
      {"Kraftwerk", "Trans Europa Express", %{year: 1977, genres: ["Electronic"]}},
      {"Miles Davis", "Kind of Blue", %{year: 1959, genres: ["Jazz"], copy: %{format: ["LP"]}}}
    ]

    wishlist = [
      {"Can", "Tago Mago", %{year: 1971, genres: ["Rock", "Krautrock"]}},
      {"Nina Simone", "Pastel Blues", %{year: 1965, genres: ["Jazz", "Blues"]}}
    ]

    for {artist, title, attrs} <- collection, {artist, title} not in existing do
      Records.add_to_collection!(artist, title, attrs, opts)
    end

    for {artist, title, attrs} <- wishlist, {artist, title} not in existing do
      Records.add_to_wishlist!(artist, title, attrs, opts)
    end
end
