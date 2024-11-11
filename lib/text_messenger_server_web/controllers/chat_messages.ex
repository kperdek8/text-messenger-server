defmodule TextMessengerServerWeb.ChatMessagesController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Protobuf
  alias TextMessengerServer.Chats

  def fetch_messages(conn, %{"id" => id}) do
    # TODO: Rethink schema

    {:ok, messages} = Chats.get_chat_messages(id)

    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Protobuf.ChatMessages.encode(messages))
  end
end
