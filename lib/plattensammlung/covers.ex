defmodule Plattensammlung.Covers do
  @moduledoc """
  Stores album covers on disk so the collection does not depend on external
  services (see ADR 0007). Files live in the `:covers_dir` directory and are
  served by the endpoint under `/covers`.
  """
  alias Plattensammlung.Lookup.HTTP

  require Logger

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
      write(response.body, extension)
    end
  end

  @doc """
  Stores an uploaded image file and returns its local URL. The type is taken
  from the file content, not from the name or what the browser claims.
  """
  @spec store_file(Path.t()) :: {:ok, String.t()} | {:error, term()}
  def store_file(path) do
    with {:ok, binary} <- File.read(path),
         :ok <- check_size(binary),
         {:ok, extension} <- detect_type(binary) do
      write(binary, extension)
    end
  end

  defp write(binary, extension) do
    name = Ash.UUIDv7.generate() <> extension
    File.mkdir_p!(dir())
    File.write!(Path.join(dir(), name), binary)
    {:ok, "/covers/" <> name}
  end

  # Magic bytes of the supported formats
  defp detect_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, ".jpg"}
  defp detect_type(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>), do: {:ok, ".png"}
  defp detect_type(<<"GIF8", _::binary>>), do: {:ok, ".gif"}
  defp detect_type(<<"RIFF", _size::binary-size(4), "WEBP", _::binary>>), do: {:ok, ".webp"}
  defp detect_type(_binary), do: {:error, :unsupported_image}

  @doc """
  Deletes cover files no album refers to ("Karteileichen"), e.g. after a crash
  between storing a file and saving the album. Files younger than `min_age`
  seconds (default one hour) are kept, so uploads in progress are safe.
  Runs at application start; by hand in a release:

      bin/plattensammlung rpc "Plattensammlung.Covers.cleanup_orphans()"

  Returns `{:ok, deleted_file_names}`.
  """
  def cleanup_orphans(min_age \\ 3600) do
    referenced = referenced_files()
    oldest_allowed = System.os_time(:second) - min_age

    deleted =
      case File.ls(dir()) do
        {:ok, files} ->
          for file <- files,
              file not in referenced,
              path = Path.join(dir(), file),
              {:ok, %File.Stat{type: :regular, mtime: mtime}} <- [File.stat(path, time: :posix)],
              mtime < oldest_allowed,
              :ok == File.rm(path),
              do: file

        {:error, _reason} ->
          []
      end

    if deleted != [], do: Logger.info("Deleted #{length(deleted)} unreferenced cover file(s)")
    {:ok, deleted}
  end

  # Maintenance across all albums, independent of any user: no authorization
  defp referenced_files do
    Plattensammlung.Records.Album
    |> Ash.Query.select([:cover_url])
    |> Ash.read!(authorize?: false)
    |> Enum.flat_map(fn
      %{cover_url: "/covers/" <> name} -> [name]
      _album -> []
    end)
    |> MapSet.new()
  end

  @doc """
  A copy of a locally stored cover under a new name, so two albums never share a
  file (deleting one album must not remove the other's cover). Remote URLs and
  nil are returned unchanged; a missing file gives nil.
  """
  def duplicate("/covers/" <> name) do
    with {:ok, binary} <- File.read(Path.join(dir(), Path.basename(name))),
         {:ok, url} <- write(binary, Path.extname(name)) do
      url
    else
      _ -> nil
    end
  end

  def duplicate(url), do: url

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
