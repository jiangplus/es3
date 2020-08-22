use Mix.Config

config :logger, level: :warn

config :es3,
  json_codec: Test.JSONCodec

config :es3, :kinesis,
  scheme: "https://",
  host: "kinesis.us-east-1.amazonaws.com",
  region: "us-east-1",
  port: 443

config :es3, :dynamodb,
  scheme: "http://",
  host: "localhost",
  port: 8000,
  region: "us-east-1"

config :es3, :dynamodb_streams,
  scheme: "http://",
  host: "localhost",
  port: 8000,
  region: "us-east-1"

config :es3, :lambda,
  host: "lambda.us-east-1.amazonaws.com",
  scheme: "https://",
  region: "us-east-1",
  port: 443

config :es3, :s3,
  scheme: "https://",
  host: "s3.amazonaws.com",
  region: "us-east-1"
