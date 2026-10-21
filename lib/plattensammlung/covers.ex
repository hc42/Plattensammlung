defmodule Plattensammlung.Covers do
  @moduledoc """
  Stores album covers on disk so the collection does not depend on external
  services (see ADR 0007). Files live in the `:covers_dir` directory and are
  served by the endpoint under `/covers`.
  """
  alias Plattensammlung.Lookup.HTTP

  @max_bytes 10_000_000
  @extensions %{
    "image/jpeg" => ".jpg",
    "image/png" => ".png",
    "image/webp" => ".webp",
    "image/gif" => ".gif"
  }

  def dir, do: Application.fetch_env!(:plattensammlung, :covers_dir)

  def remote?(url), do: is_binary(url) and String.starts_with?(url, ["http://", "https://"])

  @doc "Downloads an image and returns its local URL, e.g. `/covers/01J….jpg`."
  @spec store(String.t()) :: {:ok, String.t()} | {:error, term()}
  def store(url) do
    with {:ok, response} <- download(url),
         {:ok, extension} <- extension(response),
         :ok <- check_size(response.body) do
      name = Ash.UUIDv7.generate() <> extension
      File.mkdir_p!(dir())
      File.write!(Path.join(dir(), name), response.body)
      {:ok, "/covers/" <> name}
    end
  end

  @doc "Removes a locally stored cover; remote URLs and nil are ignored."
  def delete("/covers/" <> name) do
    _ = File.rm(Path.join(dir(), Path.basename(name)))
    :ok
  end

  def delete(_url), do: :ok

  # Short timeouts: a slow image host must not block adding an album for long.
  # If it fails, the album keeps the remote URL.
  defp download(url) do
    req =
      HTTP.new(
        decode_body: false,
        retry: false,
        receive_timeout: 8_000,
        connect_options: [timeout: 4_000]
      )

    case Req.get(req, url: url) do
      {:ok, %{status: 200} = response} -> {:ok, response}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp extension(response) do
    content_type =
      response
      |> Req.Response.get_header("content-type")
      |> List.first("")
      |> String.split(";")
      |> hd()
      |> String.trim()

    case Map.fetch(@extensions, content_type) do
      {:ok, extension} -> {:ok, extension}
      :error -> {:error, {:unsupported_content_type, content_type}}
    end
  end

  defp check_size(body) when byte_size(body) <= @max_bytes, do: :ok
  defp check_size(_body), do: {:error, :too_large}
end
