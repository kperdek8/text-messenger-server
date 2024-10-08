defmodule TextMessengerServer.Repo do
  use Ecto.Repo,
    otp_app: :text_messenger_server,
    adapter: Ecto.Adapters.Postgres
end
