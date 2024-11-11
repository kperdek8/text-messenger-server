defmodule TextMessengerServerWeb.ChatController do
  use TextMessengerServerWeb, :controller
  alias TextMessengerServer.Chats
  alias TextMessengerServer.Protobuf

  def fetch_chats(conn, _params) do
    {:ok, chat_list} = Chats.get_chats()

    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Protobuf.Chats.encode(chat_list))
  end
end
