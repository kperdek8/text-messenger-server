defmodule TextMessengerServerWeb.ChatController do
  use TextMessengerServerWeb, :controller
  alias TextMessengerServer.Chats
  alias TextMessengerServer.Protobuf

  def fetch_chats(conn, _params) do
    {:ok, %{id: user_id}} = Guardian.Plug.current_resource(conn)
    {:ok, chat_list} = Chats.get_chats(user_id)
    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Protobuf.Chats.encode(chat_list))
  end

  def fetch_chat(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      :error ->
        conn
        |> send_resp(400, Jason.encode!(%{error: "Invalid UUID format"}))

      {:ok, valid_uuid} ->
        case Chats.get_chat(valid_uuid) do
          {:ok, chat} ->
            conn
            |> put_resp_content_type("application/x-protobuf")
            |> send_resp(200, Protobuf.Chat.encode(chat))
          {:error, message} ->
            conn
            |> send_resp(404, Jason.encode!(%{error: message}))
        end
    end
  end

  def fetch_chat(conn, _params) do
    conn
    |> send_resp(400, Jason.encode!(%{error: "Chat ID not provided"}))
  end

  def create_chat(conn, %{"name" => name}) do
    {:ok, %{id: user_id}} = Guardian.Plug.current_resource(conn)
    chat = Chats.create_chat(name)
    Chats.add_user_to_chat(chat.id, user_id)
    Chats.set_requires_key_change(chat.id, true)
    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Protobuf.Chat.encode(chat))
  end
end
