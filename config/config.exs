# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :text_messenger_server,
  ecto_repos: [TextMessengerServer.Repo],
  generators: [timestamp_type: :utc_datetime]

# Guardian configuration
config :text_messenger_server, TextMessengerServerWeb.Auth.Guardian,
  issuer: "TextMessengerServer",
  secret_key: "to_do_read_from_env"

# Configures the endpoint
config :text_messenger_server, TextMessengerServerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: TextMessengerServerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TextMessengerServer.PubSub,
  live_view: [signing_salt: "nQ1RAQnl"],
  server: true

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :text_messenger_server, TextMessengerServer.Mailer, adapter: Swoosh.Adapters.Local

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  text_messenger_server: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mime, :types, %{
  "application/x-protobuf" => ["x-protobuf"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
