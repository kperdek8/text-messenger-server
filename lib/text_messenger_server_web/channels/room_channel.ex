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
    {:ok, %ChatMessage{id: message_id}} = Chats.insert_chat_message(chat_id, user_id, content)
    broadcast!(socket, "new_message", %{content: content, user_id: user_id, message_id: message_id})
    {:noreply, socket}
  end

  def handle_in("add_user", %{"user_id" => user_id}, socket) do
    case Chats.add_user_to_chat(socket.assigns.chat_id, user_id) do
      :ok ->
        TextMessengerServerWeb.Endpoint.broadcast("notifications:#{user_id}", "added_to_chat", %{chat_id: socket.assigns.chat_id})
        broadcast!(socket, "add_user", %{user_id: user_id})
        {:noreply, socket}

      :already_member -> {:noreply, socket}
    end
  end

  def handle_in("kick_user", %{"user_id" => user_id}, socket) do
    case Chats.remove_user_from_chat(socket.assigns.chat_id, user_id) do
      :ok ->
        TextMessengerServerWeb.Endpoint.broadcast("notifications:#{user_id}", "removed_from_chat", %{chat_id: socket.assigns.chat_id})
        broadcast!(socket, "kick_user", %{"user_id" => user_id})
        {:noreply, socket}

      :not_member ->
        {:noreply, socket}

      {:error, reason} ->
        IO.inspect(reason, label: "Unexpected behaviour when removing user")
        {:noreply, socket}
    end
  end

  intercept ["kick_user"]

  def handle_out("kick_user", %{"user_id" => user_id} = payload, socket) do
    if socket.assigns.user_id == user_id do
      # Unsubscribe the kicked user from the topic
      {:stop, :normal, socket}
    else
      # Forward the message to other clients
      push(socket, "kick_user", payload)
      {:noreply, socket}
    end
  end
end
