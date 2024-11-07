defmodule TextMessengerServerWeb.ChatMessagesController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Protobuf.ChatMessage
  alias TextMessengerServer.Protobuf.ChatMessages

  @messages [
    %ChatMessage{
      id: "11111111-1111-1111-1111-111111111111",
      user_id: "453dab88-c5be-43fa-b31a-3ea296c2fa8e",
      chat_id: "11111111-1111-1111-1111-111111111111",
      content: "Wiadomość 1 z czatu 1",
      timestamp: "2024-01-01 10:00:00"
    },
    %ChatMessage{
      id: "11111111-1111-1111-1111-111111111112",
      user_id: "4fd17dfa-c1cb-49e5-a0de-eba33dc23c9d",
      chat_id: "11111111-1111-1111-1111-111111111111",
      content: "Wiadomość 2 z czatu 1",
      timestamp: "2024-01-01 10:01:00"
    },
    %ChatMessage{
      id: "11111111-1111-1111-1111-111111111113",
      user_id: "453dab88-c5be-43fa-b31a-3ea296c2fa8e",
      chat_id: "11111111-1111-1111-1111-111111111112",
      content: "Wiadomość 2 z czatu 2",
      timestamp: "2024-01-01 10:01:00"
    }
  ]

  def fetch_messages(conn, %{"id" => id}) do
    # TODO: Replace with db
    # TODO: Rethink schema

    filtered_messages =
      @messages
      |> Enum.filter(fn %ChatMessage{chat_id: chat_id} -> chat_id == id end)

    chat_messages = %ChatMessages{messages: filtered_messages}

    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, ChatMessages.encode(chat_messages))
  end

  def post_message(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case ChatMessage.decode(body) do
      {:ok, %ChatMessage{} = message} ->
        IO.inspect(message)
        send_resp(conn, 201, "")

      _ ->
        send_resp(conn, 400, "Invalid Protobuf data")
    end
  end
end
