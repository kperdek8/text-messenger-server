defmodule TextMessengerServer.Chats do
  alias TextMessengerServer.Repo
  alias TextMessengerServer.Chats.{Chat, ChatUser, ChatMessage}
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
  Sets the `requires_key_change` field for a specific chat.
  If the field is already set to the desired value, no changes are made.
  """
  def set_requires_key_change(chat_id, value) when is_boolean(value) do
    query = from c in Chat, where: c.id == ^chat_id

    case Repo.one(query) do
      nil ->
        {:error, :chat_not_found}

      _chat ->
        Repo.update_all(
          from(c in Chat, where: c.id == ^chat_id),
          set: [requires_key_change: value]
        )

        :ok
    end
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

  def chat_requires_key_change?(chat_id) do
    query = from c in Chat,
            where: c.id == ^chat_id,
            select: c.requires_key_change

    Repo.one(query) || false
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
