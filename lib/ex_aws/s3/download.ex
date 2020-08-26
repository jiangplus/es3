defmodule ExAws.S3.Download do
  @moduledoc """
  Represents an AWS S3 file download operation
  """

  @enforce_keys ~w(bucket path dest)a
  defstruct [
    :bucket,
    :path,
    :dest,
    opts: [],
    service: :s3
  ]

  @type t :: %__MODULE__{}

  def get_chunk(op, %{start_byte: start_byte, end_byte: end_byte}, config) do
    %{body: body} =
      op.bucket
      |> ExAws.S3.get_object(op.path, range: "bytes=#{start_byte}-#{end_byte}")
      |> ExAws.request!(config)

    {start_byte, body}
  end

  def get_stream_meta(%{opts: [size: size, modified: modified]} = _op, _config) do
    {:ok, time, 0} = DateTime.from_iso8601(modified)
    time = time |> DateTime.to_unix() |> to_string
    file_attrs = %{"mtime" => time}
    {file_attrs, size}
  end

  def get_stream_meta(op, config) do
    %{headers: headers} = ExAws.S3.head_object(op.bucket, op.path) |> ExAws.request!(config)
    attrs = get_header(headers, "x-amz-meta-s3cmd-attrs")

    file_attrs =
      if attrs do
        attrs
        |> String.split("/")
        |> Enum.map(fn s ->
          [k, v] = String.split(s, ":")
          {k, v}
        end)
        |> Enum.filter(fn {k, _v} -> k == "atime" || k == "mtime" || k == "ctime" end)
        |> Enum.into(%{})
      else
        nil
      end

    size =
      headers
      |> Enum.find(fn {k, _} -> String.downcase(k) == "content-length" end)
      |> elem(1)
      |> String.to_integer()

    {file_attrs, size}
  end

  def build_chunk_stream(op, config) do
    {file_attrs, size} = get_stream_meta(op, config)

    stream = chunk_stream(size, op.opts[:chunk_size] || 1024 * 1024)

    {file_attrs, stream}
  end

  def chunk_stream(file_size, chunk_size) do
    Stream.unfold(0, fn counter ->
      start_byte = counter * chunk_size

      if start_byte >= file_size do
        nil
      else
        end_byte = (counter + 1) * chunk_size

        # byte ranges are inclusive, so we want to remove one. IE, first 500 bytes
        # is range 0-499. Also, we need it bounded by the max size of the file
        end_byte = min(end_byte, file_size) - 1

        {%{start_byte: start_byte, end_byte: end_byte}, counter + 1}
      end
    end)
  end

  def get_header(headers, key, default \\ nil) do
    kv =
      headers
      |> Enum.find(fn {k, _} -> String.downcase(k) == key end)

    case kv do
      nil -> default
      kv -> elem(kv, 1)
    end
  end
end

defimpl ExAws.Operation, for: ExAws.S3.Download do
  alias ExAws.S3.Download

  def perform(op, config) do
    op.dest
    |> File.open([:write, :delayed_write, :binary])
    |> download_to(op, config)
  end

  defp download_to({:error, e}, _op, _config), do: {:error, e}

  defp download_to({:ok, file}, op, config) do
    try do
      {file_attrs, stream} = Download.build_chunk_stream(op, config)

      stream
      |> Task.async_stream(
        fn boundaries ->
          chunk = Download.get_chunk(op, boundaries, config)
          :ok = :file.pwrite(file, [chunk])
        end,
        max_concurrency: Keyword.get(op.opts, :max_concurrency, 8),
        timeout: Keyword.get(op.opts, :timeout, 60_000)
      )
      |> Stream.run()

      File.close(file)

      if file_attrs["mtime"] do
        File.touch!(op.dest, file_attrs["mtime"] |> String.to_integer())
      end

      {:ok, :done}
    rescue
      err ->
        File.close(file)
        File.rm(op.dest)
        IO.inspect(err)
        {:error, "error downloading file"}
    end
  end

  def stream!(_op, _config) do
    raise "not supported yet"
  end
end
