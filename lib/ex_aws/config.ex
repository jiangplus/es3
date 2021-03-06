defmodule ExAws.Config do
  @moduledoc false

  # Generates the configuration for a service.
  # It starts with the defaults for a given environment
  # and then merges in the common config from the es3 config root,
  # and then finally any config specified for the particular service

  @common_config [
    :http_client,
    :json_codec,
    :access_key_id,
    :secret_access_key,
    :signer_url,
    :signer_key,
    :debug_requests,
    :region,
    :security_token,
    :retries,
    :normalize_path
  ]

  @type t :: %{} | Keyword.t()

  @doc """
  Builds a complete set of config for an operation.

  1) Defaults are pulled from `ExAws.Config.Defaults`
  2) Common values set via e.g `config :es3` are merged in.
  3) Keys set on the individual service e.g `config :es3, :s3` are merged in
  4) Finally, any configuration overrides are merged in
  """
  def new(service, opts \\ []) do
    overrides = Map.new(opts)

    service
    |> build_base(overrides)
    |> retrieve_runtime_config
    |> parse_host_for_region
  end

  def build_base(service, overrides \\ %{}) do
    json_config_path = "~/.es3config"
    json_config_file = Path.expand(json_config_path)

    json_config =
      try do
        File.read!(json_config_file) |> Jason.decode!(keys: :atoms)
      rescue
        # e in File.Error ->
        #   IO.inspect(e)
        #   %{}
        # e in Jason.DecodeError ->
        #   IO.inspect(e)
        #   %{}
        e ->
          %{}
      end

    common_config = Application.get_all_env(:es3) |> Map.new() |> Map.take(@common_config)
    service_config = Application.get_env(:es3, service, []) |> Map.new()

    region =
      (Map.get(overrides, :region) ||
         Map.get(service_config, :region) ||
         Map.get(common_config, :region) ||
         Map.get(json_config, :region) ||
         "us-east-1")
      |> retrieve_runtime_value(%{})

    defaults = ExAws.Config.Defaults.get(service, region)

    defaults
    |> Map.merge(json_config, fn _k, v1, v2 -> v2 || v1 end)
    |> Map.merge(common_config, fn _k, v1, v2 -> v2 || v1 end)
    |> Map.merge(service_config)
    |> Map.merge(overrides)
  end

  def retrieve_runtime_config(config) do
    Enum.reduce(config, config, fn
      {:host, host}, config ->
        Map.put(config, :host, retrieve_runtime_value(host, config))

      {:retries, retries}, config ->
        Map.put(config, :retries, retries)

      {:http_opts, http_opts}, config ->
        Map.put(config, :http_opts, http_opts)

      {k, v}, config ->
        case retrieve_runtime_value(v, config) do
          %{} = result -> Map.merge(config, result)
          value -> Map.put(config, k, value)
        end
    end)
  end

  def retrieve_runtime_value({:system, env_key}, _) do
    System.get_env(env_key)
  end

  def retrieve_runtime_value(:instance_role, config) do
    config
    |> ExAws.Config.AuthCache.get()
    |> Map.take([:access_key_id, :secret_access_key, :security_token])
    |> valid_map_or_nil
  end

  def retrieve_runtime_value({:awscli, profile, expiration}, _) do
    ExAws.Config.AuthCache.get(profile, expiration * 1000)
    |> Map.take([
      :source_profile,
      :role_arn,
      :access_key_id,
      :secret_access_key,
      :region,
      :signer_url,
      :signer_key,
      :security_token,
      :role_session_name,
      :external_id
    ])
    |> valid_map_or_nil
  end

  def retrieve_runtime_value(values, config) when is_list(values) do
    values
    |> Stream.map(&retrieve_runtime_value(&1, config))
    |> Enum.find(& &1)
  end

  def retrieve_runtime_value(value, _), do: value

  def parse_host_for_region(%{host: {stub, host}, region: region} = config) do
    Map.put(config, :host, String.replace(host, stub, region))
  end

  def parse_host_for_region(%{host: map, region: region} = config) when is_map(map) do
    case Map.fetch(map, region) do
      {:ok, host} -> Map.put(config, :host, host)
      :error -> "A host for region #{region} was not found in host map #{inspect(map)}"
    end
  end

  def parse_host_for_region(config), do: config

  def awscli_auth_adapter do
    Application.get_env(:es3, :awscli_auth_adapter, nil)
  end

  defp valid_map_or_nil(map) when map == %{}, do: nil
  defp valid_map_or_nil(map), do: map
end
