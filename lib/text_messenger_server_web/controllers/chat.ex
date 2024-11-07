defmodule TextMessengerServerWeb.ChatController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Protobuf.Chat
  alias TextMessengerServer.Protobuf.Chats
  alias TextMessengerServer.Protobuf.User

  @chats [
    %Chat{
      id: "11111111-1111-1111-1111-111111111111",
      users: [%User{id: "453dab88-c5be-43fa-b31a-3ea296c2fa8e", name: "User1"}, %User{id: "4fd17dfa-c1cb-49e5-a0de-eba33dc23c9d", name: "User2"}],
      name: "Czat 1"
    },
    %Chat{
      id: "11111111-1111-1111-1111-111111111112",
      users: [%User{id: "453dab88-c5be-43fa-b31a-3ea296c2fa8e", name: "User1"}, %User{id: "4fd17dfa-c1cb-49e5-a0de-eba33dc23c9d", name: "User2"}],
      name: "Czat 2"
    }
  ]

  def fetch_chats(conn, _params) do
    chat_list = %Chats{chats: @chats}

    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Chats.encode(chat_list))
  end
end
