defmodule TextMessengerServerWeb.ChatChannel do
  use Phoenix.Channel

  alias TextMessengerServer.Chats
  alias TextMessengerServer.Chats.ChatMessage

  def join("chat:" <> chat_id, _params, socket) do
    user_id = socket.assigns.user_id
    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      {:ok, assign(socket, :chat_id, chat_id)}
    else
      {:error, "You are not member of this chat"}
    end
  end

  def handle_in("new_message", %{"content" => content}, socket) do
    chat_id = socket.assigns.chat_id
    user_id = socket.assigns.user_id
    {:ok, %ChatMessage{id: message_id}} = TextMessengerServer.Chats.insert_chat_message(chat_id, user_id, content)
    broadcast!(socket, "new_message", %{content: content, user_id: user_id, message_id: message_id})
    {:noreply, socket}
  end

  def handle_in("add_user", %{"user_id" => user_id}, socket) do
    broadcast!(socket, "add_user", %{user_id: user_id})
    {:noreply, socket}
  end
end
