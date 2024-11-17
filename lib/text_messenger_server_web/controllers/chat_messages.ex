defmodule TextMessengerServerWeb.ChatMessagesController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Protobuf.{ChatMessages}
  alias TextMessengerServer.Chats

  def fetch_messages(conn, %{"id" => chat_id}) do
    {:ok, %{id: user_id}} = Guardian.Plug.current_resource(conn)
    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      {:ok, messages} = Chats.get_chat_messages(chat_id)

      conn
      |> put_resp_content_type("application/x-protobuf")
      |> send_resp(200, ChatMessages.encode(messages))
    else
      conn
      |> send_resp(403, Jason.encode!(%{error: "You are not member of this chat"}))
    end

  end

  def fetch_messages(conn, _params) do
    conn
    |> send_resp(400, Jason.encode!(%{error: "Chat ID not provided"}))
  end
end
