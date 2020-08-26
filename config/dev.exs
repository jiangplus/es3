use Mix.Config

config :es3,
  signer_url: System.get_env("ES3_SIGNER_URL"),
  signer_key: System.get_env("ES3_SIGNER_KEY"),
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION"),
  aws_host: System.get_env("AWS_HOST"),
  aws_bucket_host: System.get_env("AWS_BUCKET_HOST")
