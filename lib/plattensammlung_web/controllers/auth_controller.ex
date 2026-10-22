defmodule PlattensammlungWeb.AuthController do
  @moduledoc """
  Completes AshAuthentication sign-ins (magic link) and sign-out. Passkeys are
  handled by `PlattensammlungWeb.PasskeyController`.
  """
  use PlattensammlungWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    Plattensammlung.Metrics.sign_in(strategy(activity), :success)
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_flash(:info, "Angemeldet.")
    |> redirect(to: return_to)
  end

  def failure(conn, activity, _reason) do
    Plattensammlung.Metrics.sign_in(strategy(activity), :failure)

    conn
    |> put_flash(:error, "Der Anmeldelink ist ungültig oder abgelaufen.")
    |> redirect(to: ~p"/sign-in")
  end

  # activity is {strategy, phase}, e.g. {:magic_link, :sign_in}
  defp strategy({strategy, _phase}), do: strategy
  defp strategy(_activity), do: :unknown

  def sign_out(conn, _params) do
    conn
    |> clear_session(:plattensammlung)
    |> put_flash(:info, "Abgemeldet.")
    |> redirect(to: ~p"/sign-in")
  end
end
