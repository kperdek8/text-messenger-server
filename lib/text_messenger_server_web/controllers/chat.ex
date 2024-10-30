defmodule TextMessengerServerWeb.ChatController do
  use TextMessengerServerWeb, :controller

  alias Chat
  alias Chats

  @chats [
    %Chat{
      id: 1,
      users: [%User{id: 1, name: "User1"}, %User{id: 2, name: "User2"}],
      name: "Czat 1"
    },
    %Chat{
      id: 2,
      users: [%User{id: 1, name: "User1"}, %User{id: 2, name: "User2"}],
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
