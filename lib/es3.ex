defmodule Es3 do
  @moduledoc """
  Documentation for `Es3`.
  """

  def get_path(nil) do
    ""
  end

  def get_path(s) do
    String.replace_prefix(s, "/", "")
  end

  def unmark_etag(e_tag) do
    e_tag |> String.replace("\"", "")
  end

  @doc """
  Hello world.

  ## Examples

      iex> Es3.main(:hello)
      hello

  """
  def main() do
  end

  # s3cmd mb s3://BUCKET
  # s3cmd mb s3://BUCKET --region=REGION
  def mb(uri) do
    uri = URI.parse(uri)
    bucket = uri.host

    ExAws.S3.put_bucket(bucket, "cn-northwest-1")
    |> ExAws.request(region: "cn-northwest-1")
    # todo : remove
    |> IO.inspect()
  end

  # s3cmd rb s3://BUCKET
  def rb(uri) do
    uri = URI.parse(uri)
    bucket = uri.host

    ExAws.S3.delete_bucket(bucket) |> ExAws.request() |> IO.inspect()
  end

  # s3cmd rb s3://BUCKET
  def put(local_file_path, uri) do
    uri = URI.parse(uri)
    bucket = uri.host
    path = get_path(uri.path)

    local_file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, path)
    |> ExAws.request!()
    |> IO.inspect()
  end

  # s3cmd get s3://BUCKET/OBJECT LOCAL_FILE
  def get(uri, local_file_path) do
    uri = URI.parse(uri)
    bucket = uri.host
    path = get_path(uri.path)

    req = ExAws.S3.download_file(bucket, path, local_file_path)
    # req |> IO.inspect
    req |> ExAws.request() |> IO.inspect()
  end

  # s3cmd rb s3://BUCKET
  def ls() do
    buckets = ExAws.S3.list_buckets() |> ExAws.request!()

    Enum.each(buckets.body.buckets, fn bucket ->
      IO.puts("#{bucket.creation_date} #{bucket.name}")
    end)
  end

  def ls(uri) do
    uri = URI.parse(uri)
    bucket = uri.host
    path = get_path(uri.path)
    res = ExAws.S3.list_objects(bucket, prefix: path, delimiter: "/") |> ExAws.request!()

    Enum.each(res.body.common_prefixes, fn item ->
      IO.puts("DIR s3://#{bucket}/#{item.prefix}")
    end)

    Enum.each(res.body.contents, fn item ->
      # IO.inspect(item) # todo : remove

      IO.puts(
        "#{item.last_modified} #{item.size} #{item.e_tag |> unmark_etag} s3://#{bucket}/#{
          item.key
        }"
      )
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

  # s3cmd rb s3://BUCKET
  def rm(uri) do
    uri = URI.parse(uri)
    bucket = uri.host
    path = get_path(uri.path)

    ExAws.S3.delete_object(bucket, path) |> ExAws.request() |> IO.inspect()
  end

  def parse_acl(doc) do
    import SweetXml

    doc
    |> xpath(
      ~x"//AccessControlPolicy/AccessControlList"l,
      name: ~x"./Grant/Grantee/ID/text()",
      permission: ~x"./Grant/Permission/text()"
    )
  end

  def stat(uri) do
    uri = URI.parse(uri)
    bucket = uri.host
    path = get_path(uri.path)

    info = ExAws.S3.get_object_acl(bucket, path) |> ExAws.request!()

    acl =
      info.body
      |> parse_acl
      |> Enum.map_join(",", fn x ->
        "#{x.name}: #{x.permission}"
      end)

    info = ExAws.S3.head_object(bucket, path) |> ExAws.request!()
    headers = info.headers
    IO.puts("key:       #{uri}")
    IO.puts("File size: #{get_header(headers, "content-length")}")
    IO.puts("Last mod:  #{get_header(headers, "last-modified")}")
    IO.puts("MIME type: #{get_header(headers, "content-type")}")
    IO.puts("Storage:   #{get_header(headers, "x-amz-storage-class", "STANDARD")}")
    IO.puts("version:   #{get_header(headers, "x-amz-version-id")}")
    IO.puts("MD5 sum:   #{get_header(headers, "etag")}")
    IO.puts("acl:       #{acl}")
    IO.puts("attrs:     #{get_header(headers, "x-amz-meta-s3cmd-attrs")}")
    IO.puts("encrypt:   #{get_header(headers, "x-amz-server-side-encryption")}")
    ts = get_header(headers, "last-modified")
    ts |> IO.inspect()
  end

  def fstat(name) do
    File.stat!(name) |> IO.inspect()
  end

  def sync(source, dest, opts \\ []) do
    unless String.ends_with?(dest, "/") do
      raise "the dest must end with /"
    end

    source = URI.parse(source)
    dest = URI.parse(dest)

    case {source, dest} do
      {%URI{scheme: "s3"}, %URI{scheme: "s3"}} ->
        IO.puts("both source and dest are s3 address is not supported")

      {%URI{scheme: "s3"}, _} ->
        downsync(source, dest, opts)

      {_, %URI{scheme: "s3"}} ->
        upsync(source, dest, opts)

      {_, _} ->
        IO.puts("not supported")
    end
  end

  def upsync(source, dest, _opts) do
    bucket = dest.host
    path = dest.path |> String.replace_prefix("/", "") |> String.replace_suffix("/", "")
    local_dir = source.path

    res = ExAws.S3.list_objects(bucket, prefix: path, delimiter: "") |> ExAws.stream!()
    list = for n <- res, into: %{}, do: {n.key, n.e_tag |> unmark_etag}

    remote_dir =
      if String.ends_with?(source.path, "/") do
        path
      else
        Path.join(path, Path.basename(local_dir))
      end

    items =
      if File.exists?(local_dir) && File.regular?(local_dir) do
        [local_dir]
      else
        Path.wildcard(Path.join(local_dir, "**/*"))
      end

    # items |> IO.inspect() # todo : remove

    result =
      Enum.map(items, fn item ->
        if File.regular?(item) do
          md5 = file_md5(item)
          remote_path = String.replace_prefix(item, local_dir, remote_dir)

          if list[remote_path] == md5 do
            IO.puts("skip:   #{item} #{md5} -> #{remote_path} #{list[remote_path]}")

            {:skip}
          else
            ExAws.S3.put_object(bucket, remote_path, File.read!(item)) |> ExAws.request!()
            IO.puts("upload: #{item} #{md5} -> #{remote_path} #{list[remote_path]}")

            # for bucket versioning
            # {_key, value} = get_key(resp.headers, "x-amz-version-id")

            {:upload}
          end
        end
      end)

    result
  end

  def downsync(source, dest, _opts) do
    bucket = source.host
    raw_path = source.path
    path = source.path |> String.replace_prefix("/", "")
    local_dir = dest.path

    # IO.inspect({bucket, raw_path, path, local_dir})

    resp =
      ExAws.S3.list_objects(bucket, prefix: path, delimiter: "")
      |> ExAws.stream!()
      |> Enum.to_list()

    # todo : remove
    resp |> IO.inspect()

    _result =
      Enum.map(resp, fn %{e_tag: e_tag, key: key, size: size, last_modified: modified} ->
        e_tag = e_tag |> unmark_etag
        size = String.to_integer(size)

        local_file_path =
          if String.ends_with?(raw_path, "/") do
            Path.join(local_dir, String.replace_prefix(key, path, ""))
          else
            Path.join([local_dir, Path.basename(path) <> String.replace_prefix(key, path, "")])
          end

        local_file_dir = Path.dirname(local_file_path)

        if File.exists?(local_file_path) && file_md5(local_file_path) == e_tag do
          IO.puts("skip #{key} #{e_tag} -> #{local_file_path}")
        else
          res =
            ExAws.S3.download_file(bucket, key, local_file_path, size: size, modified: modified)
            |> ExAws.request()

          case res do
            {:ok, _done} ->
              IO.puts("download #{key} #{e_tag} -> #{local_file_path}")

            {:error, :enoent} ->
              # IO.puts("mkdir #{local_file_dir}")
              File.mkdir_p!(local_file_dir)

              ExAws.S3.download_file(bucket, key, local_file_path,
                size: size,
                modified: modified
              )
              |> ExAws.request()

              IO.puts("download #{key} #{e_tag} -> #{local_file_path}")

            {:error, reason} ->
              IO.puts("Error: #{reason}")
          end
        end
      end)
  end

  def file_md5(filename) do
    File.stream!(filename, [], 2048)
    |> Enum.reduce(:crypto.hash_init(:md5), fn line, acc -> :crypto.hash_update(acc, line) end)
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end

  def get_key(list, key) do
    Enum.find(list, fn {x, _y} -> x == key end)
  end
end
