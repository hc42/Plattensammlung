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
  # The path is LiveView's temporary upload file, never user input
  # sobelow_skip ["Traversal.FileModule"]
  def store_file(path) do
    with {:ok, binary} <- File.read(path),
         :ok <- check_size(binary),
         {:ok, extension} <- detect_type(binary) do
      write(binary, extension)
    end
  end

  # Name generated here (UUID + fixed extension)
  # sobelow_skip ["Traversal.FileModule"]
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
  # Only names listed from the covers directory itself
  # sobelow_skip ["Traversal.FileModule"]
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

  @doc "Removes a locally stored cover; remote URLs and nil are ignored."
  # Path.basename/1 strips any directory part ("../")
  # sobelow_skip ["Traversal.FileModule"]
  def delete("/covers/" <> name) do
    _ = File.rm(Path.join(dir(), Path.basename(name)))
    :ok
  end

  def delete(_url), do: :ok

  @doc "Hosts covers may be downloaded from; subdomains count too."
  def hosts, do: Application.fetch_env!(:plattensammlung, :cover_hosts)

  @doc "Whether `url` is an https URL on one of the cover hosts."
  def allowed_url?(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: "https", host: "" <> host, userinfo: nil}} ->
        host = String.downcase(host)
        Enum.any?(hosts(), &(host == &1 or String.ends_with?(host, "." <> &1)))

      _ ->
        false
    end
  end

  def allowed_url?(_url), do: false

  # Short timeouts: a slow image host must not block adding an album for long.
  # If it fails, the album keeps the remote URL. Redirects are followed by hand,
  # so every hop must be an allowed host (no requests into the local network).
  defp download(url, redirects_left \\ 3) do
    req =
      HTTP.new(
        decode_body: false,
        retry: false,
        redirect: false,
        receive_timeout: 8_000,
        connect_options: [timeout: 4_000]
      )

    with true <- allowed_url?(url) || {:error, :host_not_allowed} do
      case Req.get(req, url: url) do
        {:ok, %{status: 200} = response} ->
          {:ok, response}

        {:ok, %{status: status} = response}
        when status in [301, 302, 303, 307, 308] and redirects_left > 0 ->
          case Req.Response.get_header(response, "location") do
            [location | _] ->
              download(url |> URI.merge(location) |> to_string(), redirects_left - 1)

            [] ->
              {:error, {:http_status, status}}
          end

        {:ok, %{status: status}} ->
          {:error, {:http_status, status}}

        {:error, exception} ->
          {:error, exception}
      end
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
