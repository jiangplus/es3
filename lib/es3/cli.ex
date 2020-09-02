defmodule Es3.CLI do
  @moduledoc """
  Documentation for `Es3`.
  """

  @help_string """
  es3 client
  """

  def ls([uri] = _args, _opts) do
    Es3.ls(uri)
  end

  def ls([] = _args, _opts) do
    Es3.ls()
  end

  def stat([uri] = _args, _opts) do
    Es3.stat(uri)
  end

  def setacl([uri] = _args, opts) do
    Es3.setacl(uri, opts)
  end

  def get([source, dest] = _args, _opts) do
    Es3.get(source, dest)
  end

  def get([source, dest] = _args, _opts) do
    dest = Path.basename(source)
    Es3.get(source, dest)
  end

  def get(_) do
    IO.puts("""
    get dir
    Es3 get <source> <local_file>
    """)
  end

  def put([source, dest] = _args, _opts) do
    Es3.put(source, dest)
  end

  def put(_) do
    IO.puts("""
    put dir
    Es3 put <local_file> <dest>
    """)
  end

  def rm([uri] = _args, _opts) do
    Es3.rm(uri)
  end

  def rm(_) do
    IO.puts("""
    rm file
    Es3 rm <object>
    """)
  end

  def sync([source, dest] = _args, _opts) do
    Es3.sync(source, dest)
  end

  def sync(_) do
    IO.puts("""
    sync dir
    Es3 sync <source> <dest>
    """)
  end

  def msync(args, _opts) do
    Enum.each(args, fn item ->
      [source, dest] = String.split(item, "::")
      Es3.sync(source, dest)
    end)
  end

  def msync(_) do
    IO.puts("""
    sync muliiple dir
    Es3 msync <source> <dest>
    """)
  end

  def main(args) do
    options = [
      switches: [
        access_key: :string,
        secret_key: :string,
        ssl: :string,
        no_ssl: :string,
        acl_public: :boolean,
        acl_private: :boolean,
        acl_grant: :string,
        acl_revoke: :string,
        host: :string,
        host_bucket: :string,
        region: :string
      ]
    ]

    {opts, arglist, _} = OptionParser.parse(args, options)
    IO.puts("")

    try do
      case arglist do
        ["info" | args] -> stat(args, opts)
        ["setacl" | args] -> setacl(args, opts)
        ["get" | args] -> get(args, opts)
        ["put" | args] -> put(args, opts)
        ["ls" | args] -> ls(args, opts)
        ["rm" | args] -> rm(args, opts)
        ["sync" | args] -> sync(args, opts)
        _ -> IO.puts(@help_string)
      end
    rescue
      e in RuntimeError ->
        IO.puts(e.message)
    end
  end
end
