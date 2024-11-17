defmodule TextMessengerServerWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline, otp_app: :text_messenger_server,
    module: TextMessengerServerWeb.Auth.Guardian,
    error_handler: TextMessengerServerWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, allow_blank: false
end