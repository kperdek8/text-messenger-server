defmodule TextMessengerServerWeb.ChatChannel do
  use Phoenix.Channel

  alias TextMessengerServer.GroupKeyChangeETS
  alias TextMessengerServer.Chats
  alias TextMessengerServer.Chats.ChatMessage
  alias TextMessengerServer.Keys
  alias TextMessengerServer.Protobuf.{GroupKeys}

  require Logger

  def join("chat:" <> chat_id, _params, socket) do
    user_id = socket.assigns.user_id
    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      socket = assign(socket, :chat_id, chat_id)
      if Chats.chat_requires_key_change?(chat_id) do
        send(self(), :send_key_change_request)
      end

      {:ok, socket}
    else
      {:error, "You are not member of this chat"}
    end
  end

  def handle_in("new_message", %{"content" => encoded_content, "iv" => encoded_iv}, socket) do
    chat_id = socket.assigns.chat_id
    user_id = socket.assigns.user_id

    if Chats.chat_requires_key_change?(chat_id) do
      {:reply, {:error, %{error: "key_change_required"}}, socket}
    else
      {:ok, iv} = Base.decode64(encoded_iv)
      {:ok, content} = Base.decode64(encoded_content)

      case Chats.insert_chat_message(chat_id, user_id, content, iv) do
        {:ok, %ChatMessage{id: message_id}} ->
          broadcast!(socket, "new_message", %{
            content: encoded_content,
            user_id: user_id,
            message_id: message_id,
            iv: encoded_iv
          })

          {:reply, {:ok, %{message: "message_received"}}, socket}

        {:error, reason} ->
          Logger.error("Failed to insert chat message: #{inspect(reason)}")
          {:reply, {:error, %{error: "Failed to send message"}}, socket}
      end
    end
  end

  # Ignore incorrect payload
  def handle_in("new_message", payload, socket) do
    Logger.debug("Incorrect payload in socket message `new_message`: #{inspect(payload)}}")
    {:noreply, socket}
  end

  def handle_in("add_user", %{"user_id" => user_id}, socket) do
    chat_id = socket.assigns.chat_id
    case Chats.add_user_to_chat(socket.assigns.chat_id, user_id) do
      :ok ->
        TextMessengerServerWeb.Endpoint.broadcast("notifications:#{user_id}", "added_to_chat", %{chat_id: socket.assigns.chat_id})
        broadcast_from!(socket, "add_user", %{user_id: user_id})

        Chats.set_requires_key_change(chat_id, true)

        {:noreply, socket}

      :already_member -> {:noreply, socket}
    end
  end

  def handle_in("add_user", payload, socket) do
    Logger.debug("Incorrect payload in socket message `add_user`: #{inspect(payload)}}")
    {:noreply, socket}
  end

  def handle_in("change_group_key", %{"group_keys" => base64_encoded_group_keys}, socket) do
    chat_id = socket.assigns.chat_id
    {:ok, encoded_group_keys} = Base.decode64(base64_encoded_group_keys)
    # Step 1: Decode and validate group keys count
    with %GroupKeys{} = group_keys <- GroupKeys.decode(encoded_group_keys),
         :ok <- Keys.validate_group_keys_count(chat_id, group_keys) do
      # Step 2: Check if group key change is already in progress using ETS
      if GroupKeyChangeETS.in_progress?(chat_id) do
        # If the change is already in progress, respond with an error
        {:reply, {:error, %{error: "Group key change already in progress"}}, socket}
      else
        # Step 3: Set the in_progress flag in ETS to avoid concurrent changes
        GroupKeyChangeETS.set_in_progress(chat_id, true)

        # Step 4: Proceed with the group key change
        case Keys.change_group_key(chat_id, group_keys) do
          {:ok, :group_keys_inserted} ->
            # Step 5: Successfully changed the group key, now reset the flag in database
            Chats.set_requires_key_change(chat_id, false)

            # Broadcast key change
            broadcast!(socket, "group_key_changed", %{chat_id: chat_id})
            GroupKeyChangeETS.set_in_progress(chat_id, false)
            {:reply, {:ok, %{message: "Group key changed successfully"}}, socket}

          _ ->
            # If something fails during the group key insertion, reset the flag in ETS and send an error
            GroupKeyChangeETS.set_in_progress(chat_id, false)
            {:reply, {:error, %{error: "Failed to change group key"}}, socket}
        end
      end
    else
      # Handle errors related to invalid group keys or member count mismatch
      {:error, :key_member_count_mismatch} ->
        {:reply, {:error, %{error: "Number of keys does not match number of members in chat"}}, socket}

      _ ->
        {:reply, {:error, %{error: "Failed to decode or validate group keys"}}, socket}
    end
  end

  def handle_in("change_group_key", payload, socket) do
    Logger.debug("Incorrect payload in socket message `change_group_key`: #{inspect(payload)}}")
    {:noreply, socket}
  end

  def handle_in("kick_user", %{"user_id" => user_id}, socket) do
    chat_id = socket.assigns.chat_id
    case Chats.remove_user_from_chat(socket.assigns.chat_id, user_id) do
      :ok ->
        TextMessengerServerWeb.Endpoint.broadcast("notifications:#{user_id}", "removed_from_chat", %{chat_id: socket.assigns.chat_id})
        broadcast_from!(socket, "kick_user", %{"user_id" => user_id})

        Chats.set_requires_key_change(chat_id, true)

        {:noreply, socket}

      :not_member ->
        {:noreply, socket}

      {:error, reason} ->
        IO.inspect(reason, label: "Unexpected behaviour when removing user")
        {:noreply, socket}
    end
  end

  def handle_in("kick_user", payload, socket) do
    Logger.debug("Incorrect payload in socket message `kick_user`: #{inspect(payload)}}")
    {:noreply, socket}
  end

  def handle_info(:send_key_change_request, socket) do
    chat_id = socket.assigns.chat_id
    push(socket, "change_key_request", %{chat_id: chat_id})
    {:noreply, socket}
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
