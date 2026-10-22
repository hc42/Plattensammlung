defmodule Plattensammlung.Lookup.HTTP do
  @moduledoc """
  Shared `Req` setup for external services. Tests inject a stub through the
  `:req_options` config (see `config/test.exs`).
  """

  @doc "Builds a Req request with a descriptive user agent and the configured options."
  def new(opts \\ []) do
    [user_agent: user_agent(), receive_timeout: 10_000, retry: :transient, max_retries: 2]
    |> Keyword.merge(opts)
    |> Keyword.merge(Application.get_env(:plattensammlung, :req_options, []))
    |> Req.new()
    # A span per request in traces (ADR 0019); no trace headers to other services
    |> OpentelemetryReq.attach()
  end

  @doc """
  MusicBrainz asks for an application name and contact; the contact comes from
  `MUSICBRAINZ_CONTACT` (an e-mail address or URL) when set.
  """
  def user_agent do
    case Application.get_env(:plattensammlung, :musicbrainz_contact) do
      contact when contact in [nil, ""] -> "Plattensammlung/0.1"
      contact -> "Plattensammlung/0.1 ( #{contact} )"
    end
  end

  @doc "GET returning the decoded body for status 200."
  def get_json(req, path, params) do
    case Req.get(req, url: path, params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> {:ok, nil}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, exception} -> {:error, exception}
    end
  end
end
