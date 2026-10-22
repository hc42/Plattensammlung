defmodule Plattensammlung.Accounts.Changes.DeleteAccountData do
  @moduledoc """
  Clears out a user's data for `User.delete_account` (ADR 0023):

    * before the transaction: every album the user has is removed from their
      collection and wishlist with `Records.remove_album/2`, the same as
      "Remove" on the album page. Albums no one else has go with cover and
      artist; the others keep theirs.
    * in the transaction: API keys and the stored tokens are deleted (which
      also ends every session, `require_token_presence_for_authentication?`).
      Passkeys, copies and wishes would go with the user row anyway
      (`on_delete: :delete`).
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Plattensammlung.{Accounts, Records}

  @impl true
  def change(changeset, _opts, context) do
    user = changeset.data
    opts = Ash.Context.to_opts(context)

    changeset
    # remove_album runs without a surrounding transaction (cover files are
    # deleted after its commit), so it can't run inside this action's one
    |> Ash.Changeset.before_transaction(fn changeset ->
      for status <- [:collection, :wishlist],
          album <- Records.search_albums!(nil, status, opts) do
        Records.remove_album!(album.id, opts)
      end

      changeset
    end)
    |> Ash.Changeset.before_action(fn changeset ->
      Enum.each(Accounts.list_api_keys!(opts), &Accounts.destroy_api_key!(&1, opts))

      # Tokens belong to AshAuthentication and are only reachable without a
      # policy; the filter limits this to the user's own
      subject = AshAuthentication.user_to_subject(user)

      Plattensammlung.Accounts.Token
      |> Ash.Query.filter(subject == ^subject)
      |> Ash.bulk_destroy!(:expunge_for_subject, %{}, authorize?: false, strategy: :stream)

      changeset
    end)
  end
end
