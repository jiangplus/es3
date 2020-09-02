use Mix.Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

import_config "#{Mix.env()}.exs"

config :es3,
  # todo : load es3 config file from env, now default to $HOME/.es3config
  # es3_config: (System.get_env("ES3_CONFIG") || "~/.es3config"),
  signer_url: System.get_env("ES3_SIGNER_URL"),
  signer_key: System.get_env("ES3_SIGNER_KEY"),
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION"),
  host: System.get_env("AWS_HOST"),
  bucket_host: System.get_env("AWS_BUCKET_HOST")
