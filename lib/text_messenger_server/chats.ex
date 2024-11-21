defmodule TextMessengerServer.Chats do
  alias TextMessengerServer.Repo
  alias TextMessengerServer.Chats.{Chat, ChatUser, ChatMessage, GroupKey}
  alias TextMessengerServer.Protobuf
  alias TextMessengerServer.Accounts.{User}

  import Ecto.Query

  @doc """
  Creates a new chat with the specified name.
  """
  def create_chat(name) do
    %Chat{}
    |> Chat.changeset(%{name: name})
    |> Repo.insert!()
    |> Repo.preload(:users)
    |> to_protobuf_chat()
  end

  @doc """
  Fetches a chat by ID and converts it to Protobuf format.
  """
  def get_chat(id) do
    chat =
      from(c in Chat, where: c.id == ^id, select: [:id, :name])
      |> Repo.one()
      |> Repo.preload(:users)

    case chat do
      nil -> {:error, "Chat not found"}
      chat -> {:ok, to_protobuf_chat(chat)}
    end
  end

  @doc """
  Fetches all chats available to user and converts it to Protobuf format.
  """
  def get_chats(user_id) do
    chats =
      from(c in Chat,
        join: cu in ChatUser,
        on: cu.chat_id == c.id,
        where: cu.user_id == ^user_id,
        select: c,
        preload: [:users]
      )
      |> Repo.all()
      |> to_protobuf_chats()

    {:ok, chats}
  end

  @doc """
  Adds a user to a chat by creating an entry in the ChatUser join table.
  """
  def add_user_to_chat(chat_id, user_id) do
    case Repo.get_by(ChatUser, chat_id: chat_id, user_id: user_id) do
      nil ->
        %ChatUser{}
        |> ChatUser.changeset(%{chat_id: chat_id, user_id: user_id})
        |> Repo.insert()
        :ok

      _chat_user ->
        :already_member
    end
  end

  @doc """
  Removes a user from a chat by deleting the entry in the ChatUser join table.
  """
  def remove_user_from_chat(chat_id, user_id) do
    query = from cu in ChatUser,
            where: cu.chat_id == ^chat_id and cu.user_id == ^user_id

    case Repo.delete_all(query) do
      {0, _} -> :not_member
      {1, _} -> :ok
      {count, _} when count > 1 -> {:error, "Multiple associations found, which shouldn't happen"}
    end
  end

  @doc """
  Fetches users in a specific chat and returns them in Protobuf format.
  """
  def get_chat_members(chat_id) do
    users =
      from(u in User,
        join: cu in ChatUser,
        on: cu.user_id == u.id,
        where: cu.chat_id == ^chat_id,
        select: [:id, :username]
      )
      |> Repo.all()
      |> to_protobuf_users()

    {:ok, users}
  end

  @doc """
  Fetches messages for a specific chat and returns them in Protobuf format.
  """
  def get_chat_messages(chat_id) do
    messages =
      from(m in ChatMessage,
        where: m.chat_id == ^chat_id,
        select: [:id, :user_id, :chat_id, :content, :timestamp],
        order_by: [desc: m.timestamp]
      )
      |> Repo.all()
      |> to_protobuf_messages()

    {:ok, messages}
  end

  @doc """
  Inserts a new message into a specified chat.
  """
  # TODO: Remove default iv after implementation of endpoint
  def insert_chat_message(chat_id, user_id, content, iv \\ <<1, 2, 3, 4>>) do
    query = from c in TextMessengerServer.Chats.Chat,
            where: c.id == ^chat_id,
            select: c.current_key_number

    case Repo.one(query) do
      nil ->
        {:error, :chat_not_found}

      current_key_number ->
        %ChatMessage{}
        |> ChatMessage.changeset(%{
          chat_id: chat_id,
          user_id: user_id,
          content: content,
          iv: iv,
          timestamp: DateTime.utc_now(),
          key_number: current_key_number
        })
        |> Repo.insert()
    end
  end

  @doc """
  Fetch the newest group key for a specific chat and user, sorted by key_number.
  """
  def get_latest_group_key(chat_id, user_id) do
    GroupKey
    |> where([gk], gk.chat_id == ^chat_id and gk.user_id == ^user_id)
    |> order_by([gk], desc: gk.key_number)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Fetch all group keys for a specific chat and user, sorted by key_number.
  """
  def get_all_group_keys(chat_id, user_id) do
    GroupKey
    |> where([gk], gk.chat_id == ^chat_id and gk.user_id == ^user_id)
    |> order_by([gk], asc: gk.key_number)  # Sort by key_number in ascending order
    |> Repo.all()
  end

  @doc """
  Changes group key by inserting it and incrementing key number.
  """
  def change_group_key(chat_id, %Protobuf.GroupKeys{group_keys: group_keys}) do
    Repo.transaction(fn ->
      # 1. Check if group_keys has one key per each chat member
      users_count = get_chat_users_count(chat_id)
      group_keys_count = length(group_keys)

      if group_keys_count != users_count do
        {:error, :key_member_count_mismatch}
      else
        # 2. Increment the group key number for the chat
        case increment_key_number(chat_id) do
          {:error, reason} ->
            # Rollback and return error if incrementing key number fails
            {:error, reason}
          {:ok, key_number} ->
            # 3. Insert the group keys into the database
            case insert_group_keys(chat_id, group_keys, key_number) do
              :ok ->
                # Return success if all group keys were inserted
                :group_keys_inserted
              {:error, reason} ->
                # Rollback and return error if insertion fails
                {:error, reason}
            end
        end
      end
    end)
  end

  @doc """
  Verifies if user is member of specific chat.
  """
  def is_user_member_of_chat?(user_id, chat_id) do
    query = from c in Chat,
            join: u in assoc(c, :users),
            where: c.id == ^chat_id and u.id == ^user_id,
            select: u.id

    Repo.exists?(query)
  end

  # Private functions

  # Fetch number of users in the chat
  defp get_chat_users_count(chat_id) do
    Repo.one(
      from cu in ChatUser,
      where: cu.chat_id == ^chat_id,
      select: count(cu.user_id)
    )
  end

  # Increment key number for specified chat
  defp increment_key_number(chat_id) do
    from(c in TextMessengerServer.Chats.Chat,
      where: c.id == ^chat_id,
      update: [set: [current_key_number: c.current_key_number + 1]],
      select: c.current_key_number
    )
    |> Repo.update_all([])
    |> case do
      {0, _} -> {:error, :chat_not_found}
      {1, [new_key_number]} -> {:ok, new_key_number}
      _ -> {:error, :unexpected_result}
    end
  end

  # Insert the group keys into the database for each user
  defp insert_group_keys(chat_id, group_keys, key_number) do
    Enum.each(group_keys, fn %Protobuf.GroupKey{user_id: user_id, encrypted_key: key} ->
      case insert_group_key(chat_id, user_id, key, key_number) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Insert a new group key into the database
  defp insert_group_key(chat_id, user_id, encrypted_key, key_number) do
    %GroupKey{}
    |> GroupKey.changeset(%{
      chat_id: chat_id,
      user_id: user_id,
      encrypted_key: encrypted_key,
      key_number: key_number
    })
    |> Repo.insert()
    |> case do
      {:ok, _group_key} -> :ok
      {:error, %{errors: errors}} -> {:error, "Failed to insert group key: #{errors}"}
    end
  end

  # Conversion Functions

  defp to_protobuf_user(%User{id: id, username: username}) do
    %Protobuf.User{
      id: Ecto.UUID.cast!(id),
      name: username
    }
  end

  defp to_protobuf_users(users) do
    %Protobuf.Users{
      users: Enum.map(users, &to_protobuf_user/1)
    }
  end

  defp to_protobuf_chat(%Chat{id: id, name: name, users: users}) do
    %Protobuf.Chat{
      id: Ecto.UUID.cast!(id),
      name: name,
      users: Enum.map(users, &to_protobuf_user/1)
    }
  end

  defp to_protobuf_chats(chats) do
    %Protobuf.Chats{
      chats: Enum.map(chats, &to_protobuf_chat/1)
    }
  end

  defp to_protobuf_message(%ChatMessage{id: id, user_id: user_id, chat_id: chat_id, content: content, timestamp: timestamp}) do
    %Protobuf.ChatMessage{
      id: Ecto.UUID.cast!(id),
      user_id: Ecto.UUID.cast!(user_id),
      chat_id: Ecto.UUID.cast!(chat_id),
      content: content,
      timestamp: DateTime.to_string(timestamp)
    }
  end

  defp to_protobuf_messages(messages) do
    %Protobuf.ChatMessages{
      messages: Enum.map(messages, &to_protobuf_message/1)
    }
  end
end
