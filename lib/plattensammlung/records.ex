defmodule Plattensammlung.Records do
  @moduledoc """
  Domain for the record collection: shared artists and albums, and each user's
  copies and wishes (ADR 0016).

  A domain groups related resources and exposes a *code interface*: plain functions
  such as `add_to_collection/3` that run a resource action. LiveViews, the JSON API
  and seeds call these functions instead of touching the database directly.
  """
  use Ash.Domain, otp_app: :plattensammlung, extensions: [AshJsonApi.Domain]

  # JSON:API endpoints under /api/json (see ADR 0004). Each route runs an Ash
  # action, so the API follows the same rules as the web UI.
  json_api do
    routes do
      base_route "/artists", Plattensammlung.Records.Artist do
        index :read
        get :read
        post :create
        patch :update
        delete :destroy
        related :albums, :read
      end

      base_route "/albums", Plattensammlung.Records.Album do
        # Before `get`, so "lookup" is not taken for an album id
        route :get, "/lookup", :lookup
        route :get, "/statistics", :statistics
        route :get, "/:album_id/matches", :find_matches
        patch :apply_match, route: "/:id/match"
        index :search
        get :read
        # Generic actions: they answer with the album as plain JSON
        route :post, "/collection", :add_to_collection
        route :post, "/wishlist", :add_to_wishlist
        route :delete, "/:album_id/mine", :remove
        patch :update
        patch :mark_wanted, route: "/:id/wanted"
        patch :unmark_wanted, route: "/:id/unwanted"
        delete :destroy
        related :copies, :read
      end

      base_route "/copies", Plattensammlung.Records.Copy do
        get :read
        post :create
        patch :update
        delete :destroy
      end

      base_route "/wishes", Plattensammlung.Records.Wish do
        index :read
        post :create
        delete :destroy
      end
    end
  end

  resources do
    resource Plattensammlung.Records.Artist do
      define :list_artists, action: :read
      define :get_artist, action: :read, get_by: [:id]
      define :get_artist_by_name, action: :read, get_by: [:name]
      define :create_artist, action: :create, args: [:name]
      define :update_artist, action: :update
      define :destroy_artist, action: :destroy
    end

    resource Plattensammlung.Records.Album do
      define :add_to_collection, args: [:artist_name, :title]
      define :add_to_wishlist, args: [:artist_name, :title]
      define :remove_album, action: :remove, args: [:album_id]
      define :merge_albums, action: :merge, args: [:source_id, :target_id]
      define :create_album, action: :create, args: [:artist_name]
      define :complete_album, action: :complete
      define :get_album, action: :read, get_by: [:id]
      define :search_albums, action: :search, args: [{:optional, :query}, {:optional, :status}]
      define :find_duplicates, action: :duplicates, args: [:artist_name, :title]
      define :find_by_barcode, action: :by_barcode, args: [:barcode]
      define :lookup_albums, action: :lookup, args: [:query]
      define :find_matches, args: [:album_id, {:optional, :query}]
      define :apply_match, args: [:result, {:optional, :mode}]
      define :upload_cover, args: [:image]
      define :remove_cover
      define :find_streaming_links
      define :statistics, action: :statistics
      define :list_collection, action: :collection
      define :list_wishlist, action: :wishlist
      define :update_album, action: :update
      define :mark_wanted
      define :unmark_wanted
      define :destroy_album, action: :destroy
    end

    resource Plattensammlung.Records.Wish do
      define :add_wish, action: :create, args: [:album_id]
      define :list_wishes, action: :read
      define :destroy_wish, action: :destroy
    end

    resource Plattensammlung.Records.Copy do
      define :add_copy, action: :create, args: [:album_id]
      define :get_copy, action: :read, get_by: [:id]
      define :update_copy, action: :update
      define :destroy_copy, action: :destroy
    end
  end
end
