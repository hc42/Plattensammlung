defmodule Plattensammlung.Repo.Migrations.SharedAlbums do
  @moduledoc """
  Albums become shared (ADR 0016): copies get an owner, the wishlist moves from
  `albums.wanted` into the `wishes` table, and albums that several users had
  separately (same artist and title) are merged into one.

  Generated with `mix ash.codegen shared_albums`, then extended by hand with
  the data steps between the schema changes.
  """

  use Ecto.Migration

  def up do
    create table(:wishes, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuidv7()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :album_id,
          references(:albums,
            column: :id,
            name: "wishes_album_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :owner_id,
          references(:users,
            column: :id,
            name: "wishes_owner_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create unique_index(:wishes, [:owner_id, :album_id], name: "wishes_unique_wish_index")

    # Nullable first, filled from the album's owner, required afterwards
    alter table(:copies) do
      add :owner_id,
          references(:users,
            column: :id,
            name: "copies_owner_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )
    end

    execute """
    UPDATE copies SET owner_id = albums.owner_id
    FROM albums WHERE copies.album_id = albums.id
    """

    execute """
    INSERT INTO wishes (album_id, owner_id)
    SELECT id, owner_id FROM albums WHERE wanted
    ON CONFLICT DO NOTHING
    """

    # Merge albums with the same artist and title (title is citext, so case is
    # ignored): the oldest one stays, copies and wishes move over, gaps in its
    # data are filled from the others
    execute """
    CREATE TEMPORARY TABLE album_merge ON COMMIT DROP AS
    SELECT id, first_value(id) OVER (PARTITION BY artist_id, title ORDER BY id) AS keep
    FROM albums
    """

    execute "DELETE FROM album_merge WHERE id = keep"

    execute """
    UPDATE albums k SET
      year = COALESCE(k.year, d.year),
      cover_url = COALESCE(k.cover_url, d.cover_url),
      genres = CASE WHEN cardinality(k.genres) = 0 THEN d.genres ELSE k.genres END,
      discogs_master_id = COALESCE(k.discogs_master_id, d.discogs_master_id),
      musicbrainz_release_group_id =
        COALESCE(k.musicbrainz_release_group_id, d.musicbrainz_release_group_id),
      spotify_album_id = COALESCE(k.spotify_album_id, d.spotify_album_id),
      tidal_album_id = COALESCE(k.tidal_album_id, d.tidal_album_id)
    FROM album_merge m JOIN albums d ON d.id = m.id
    WHERE k.id = m.keep
    """

    execute "UPDATE copies c SET album_id = m.keep FROM album_merge m WHERE c.album_id = m.id"

    execute """
    INSERT INTO wishes (album_id, owner_id)
    SELECT m.keep, w.owner_id FROM wishes w JOIN album_merge m ON w.album_id = m.id
    ON CONFLICT DO NOTHING
    """

    # Their remaining wishes are deleted with them (on_delete: delete_all)
    execute "DELETE FROM albums a USING album_merge m WHERE a.id = m.id"

    execute "ALTER TABLE copies ALTER COLUMN owner_id SET NOT NULL"

    alter table(:albums) do
      remove :wanted
      remove :owner_id
    end
  end

  def down do
    # Going back gives every album exactly one owner again; that only works
    # while no album is shared by several users
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT album_id FROM (
          SELECT album_id, owner_id FROM copies UNION SELECT album_id, owner_id FROM wishes
        ) holders GROUP BY album_id HAVING count(DISTINCT owner_id) > 1
      ) THEN
        RAISE EXCEPTION 'Albums are shared by several users; rolling back would lose data.';
      END IF;
    END $$
    """

    alter table(:albums) do
      add :owner_id,
          references(:users,
            column: :id,
            name: "albums_owner_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :wanted, :boolean, null: false, default: false
    end

    execute """
    UPDATE albums a SET owner_id = h.owner_id
    FROM (
      SELECT album_id, owner_id FROM copies UNION SELECT album_id, owner_id FROM wishes
    ) h
    WHERE h.album_id = a.id
    """

    execute "UPDATE albums a SET wanted = true FROM wishes w WHERE w.album_id = a.id"

    # Albums no one had cannot get an owner
    execute "DELETE FROM albums WHERE owner_id IS NULL"
    execute "ALTER TABLE albums ALTER COLUMN owner_id SET NOT NULL"

    drop constraint(:copies, "copies_owner_id_fkey")

    alter table(:copies) do
      remove :owner_id
    end

    drop table(:wishes)
  end
end
