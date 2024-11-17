defmodule TextMessengerServerWeb.UserController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Chats
  alias TextMessengerServer.Accounts
  alias TextMessengerServer.Protobuf.{User,Users}

  def fetch_chat_members(conn, %{"id" => chat_id}) do
    {:ok, %User{id: user_id}} = Guardian.Plug.current_resource(conn)
    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      {:ok, users} = Chats.get_chat_members(chat_id)

      conn
      |> put_resp_content_type("application/x-protobuf")
      |> send_resp(200, Users.encode(users))
    else
      conn
      |> send_resp(403, Jason.encode!(%{error: "You are not member of this chat"}))
    end
  end

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
