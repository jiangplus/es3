use Mix.Config

config :es3,
  signer_url: System.get_env("SIGNER_URL"),
  signer_key: System.get_env("SIGNER_KEY"),
  access_key_id: System.get_env("AWS_ACCESS_KEY"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION")
