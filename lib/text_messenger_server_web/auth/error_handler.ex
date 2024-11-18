defmodule TextMessengerServerWeb.Auth.ErrorHandler do
  use Phoenix.Controller

  def auth_error(conn, {type, reason}, _opts) do
    IO.inspect(type, label: "Authentication error type")

    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized", reason: reason})
  end
end