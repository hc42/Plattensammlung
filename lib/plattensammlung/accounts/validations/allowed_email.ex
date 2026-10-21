defmodule Plattensammlung.Accounts.Validations.AllowedEmail do
  @moduledoc """
  Only addresses listed in `ALLOWED_EMAILS` may sign in or register.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    email = Ash.Changeset.get_attribute(changeset, :email)

    if Plattensammlung.Accounts.allowed_email?(email) do
      :ok
    else
      {:error, field: :email, message: "is not allowed to sign in"}
    end
  end
end
