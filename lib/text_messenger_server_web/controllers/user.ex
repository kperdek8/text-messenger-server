defmodule TextMessengerServerWeb.UserController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Accounts
  alias TextMessengerServer.Protobuf.User
  alias TextMessengerServer.Protobuf.Users

  def fetch_users(conn, _params) do
    {:ok, user_list} = Accounts.get_users()

    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Users.encode(user_list))
  end

  def fetch_user(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      :error ->
        conn
        |> send_resp(400, Jason.encode!(%{error: "Invalid UUID format"}))

      {:ok, valid_uuid} ->
        case Accounts.get_user(valid_uuid) do
          {:ok, user} ->
            conn
            |> put_resp_content_type("application/x-protobuf")
            |> send_resp(200, User.encode(user))
          {:error, message} ->
            conn
            |> send_resp(404, Jason.encode!(%{error: message}))
        end
    end
  end

  def fetch_user(conn, _params) do
    conn
    |> send_resp(400, Jason.encode!(%{error: "User ID not provided"}))
  end
end
