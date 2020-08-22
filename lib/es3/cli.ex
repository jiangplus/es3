defmodule Es3.CLI do
  @moduledoc """
  Documentation for `Es3`.
  """

  def ls([uri] = _params) do
    res = Es3.ls(uri)
  end
  def ls(_) do
    res = Es3.ls()
  end

  def get([source, dest] = _params) do
    res = Es3.get(source, dest)
  end
  def get(_) do
    IO.puts("""
      get dir
      Es3 get <source> <local_file>
      """)
  end

  def put([source, dest] = _params) do
    res = Es3.put(source, dest)
  end
  def put(_) do
    IO.puts("""
      put dir
      Es3 put <local_file> <dest>
      """)
  end

  def rm([uri] = _params) do
    res = Es3.rm(uri)
  end
  def rm(_) do
    IO.puts("""
      rm file
      Es3 rm <object>
      """)
  end

  def sync([source, dest] = _params) do
    res = Es3.sync(source, dest)
  end
  def sync(_) do
    IO.puts("""
      sync dir
      Es3 sync <source> <dest>
      """)
  end

  def msync(params) do
    Enum.each(fn item -> 
      [source, dest] = String.split(item, "::")
    res = Es3.sync(source, dest)
    end)
  end
  def sync(_) do
    IO.puts("""
      sync muliiple dir
      Es3 msync <source> <dest>
      """)
  end

  def main(args) do
  end
  # def main(args) do
  #   options = [switches: [access_key: :string, secret_key: :string, ssl: :string, no_ssl: :string, acl_public: :string, acl_private: :string, host: :string, host_bucket: :string, region: :string ]]
  #   {opts, arglist, _}= OptionParser.parse(args, options)
  #   IO.inspect opts, label: "Options"
  #   IO.inspect arglist, label: "Arguments"
  #   IO.puts ""
  #   IO.puts ""

  #   case arglist do
  #     ["get" | rest] -> get(rest)
  #     ["put" | rest] -> put(rest)
  #     ["ls" | rest] -> ls(rest)
  #     ["rm" | rest] -> rm(rest)
  #     ["sync" | rest] -> sync(rest)
  #     _ -> IO.puts(@help_string)
  #   end
  # end
end
