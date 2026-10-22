defmodule PlattensammlungWeb.Locale do
  @moduledoc """
  The interface language (ADR 0021): the user's choice on the account page,
  otherwise the browser's `Accept-Language`, otherwise English.

  * As a plug in the browser pipeline it sets the Gettext locale for the
    request, assigns `:locale` (for `<html lang>`) and keeps the browser's
    language in the session for LiveViews.
  * As an `on_mount` hook it sets the locale in every LiveView process.
  """
  @behaviour Plug

  import Plug.Conn

  @supported ~w(en de)
  @default "en"

  @doc "Supported locales, the default first."
  def supported, do: @supported

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    browser = conn |> get_req_header("accept-language") |> List.first() |> from_header()
    locale = user_locale(conn.assigns[:current_user]) || browser

    Gettext.put_locale(PlattensammlungWeb.Gettext, locale)

    conn
    |> put_session("browser_locale", browser)
    |> assign(:locale, locale)
  end

  def on_mount(:default, _params, session, socket) do
    locale =
      user_locale(socket.assigns[:current_user]) || session["browser_locale"] || @default

    Gettext.put_locale(PlattensammlungWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end

  @doc """
  The best supported language of an `Accept-Language` header, e.g.
  "de-DE,de;q=0.9,en;q=0.8" → "de". Falls back to English.
  """
  def from_header(nil), do: @default

  def from_header(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_entry/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_lang, quality} -> quality end, :desc)
    |> Enum.find_value(@default, fn {lang, _quality} -> lang in @supported && lang end)
  end

  # "de-DE;q=0.9" → {"de", 0.9}
  defp parse_entry(entry) do
    [tag | params] = entry |> String.trim() |> String.split(";")
    lang = tag |> String.split("-") |> hd() |> String.downcase()

    quality =
      Enum.find_value(params, 1.0, fn param ->
        case String.split(String.trim(param), "=") do
          ["q", value] -> parse_quality(value)
          _ -> nil
        end
      end)

    if lang != "" and quality > 0, do: {lang, quality}
  end

  defp parse_quality(value) do
    case Float.parse(value) do
      {quality, _rest} -> quality
      :error -> 0.0
    end
  end

  defp user_locale(%{locale: locale}) when locale in @supported, do: locale
  defp user_locale(_user), do: nil
end
