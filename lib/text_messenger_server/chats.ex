defmodule TextMessengerServer.Chats do
  alias TextMessengerServer.Repo
  alias TextMessengerServer.Chats.{Chat, ChatUser, ChatMessage}
  alias TextMessengerServer.Protobuf
  alias TextMessengerServer.Accounts.User

  import Ecto.Query

  @doc """
  Creates a new chat with the specified name.
  """
  def create_chat(name) do
    %Chat{}
    |> Chat.changeset(%{name: name})
    |> Repo.insert()
  end

  @doc """
  Fetches a chat by ID and converts it to Protobuf format.
  """
  def get_chat(id) do
    chat =
      Repo.one(from(c in Chat, where: c.id == ^id, select: [:id, :name])) |> Repo.preload(:users)

    case chat do
      nil ->
        {:error, "Chat not found"}

      %{id: id, name: name, users: users} ->
        chat_proto = %Protobuf.Chat{
          # Ensure that the id is a string UUID
          id: Ecto.UUID.cast!(id),
          name: name,
          users:
            Enum.map(users, fn user ->
              %Protobuf.User{
                # Convert UUID to string
                id: Ecto.UUID.cast!(user.id),
                name: user.username
              }
            end)
        }

        {:ok, chat_proto}
    end
  end

  @doc """
  Fetches all chats and converts it to Protobuf format.
  """
  def get_chats(user_id) do
    chats =
      from(c in Chat,
        join: cu in ChatUser,
        on: cu.chat_id == c.id,
        where: cu.user_id == ^user_id, # Fetch only chats which user belongs to
        select: c,
        preload: [:users] # Preload users for each chat
      )
      |> Repo.all()

      chats_proto = %Protobuf.Chats{
        chats:
          Enum.map(chats, fn %Chat{id: id, name: name, users: users} ->
            %Protobuf.Chat{
              id: Ecto.UUID.cast!(id),
              name: name,
              users:
                Enum.map(users, fn user ->
                  %Protobuf.User{
                    # Convert UUID to string
                    id: Ecto.UUID.cast!(user.id),
                    name: user.username
                  }
                end)
            }
          end)
      }

      {:ok, chats_proto}
  end

  @doc """
  Adds a user to a chat by creating an entry in the ChatUser join table.
  """
  def add_user_to_chat(chat_id, user_id) do
    %ChatUser{}
    |> ChatUser.changeset(%{chat_id: chat_id, user_id: user_id})
    |> Repo.insert()
  end

  @doc """
  Fetches users in a specific chat and returns them in Protobuf format.
  """
  def get_chat_members(chat_id) do
    users =
      Repo.all(
        from(u in User,
          join: cu in ChatUser,
          on: cu.user_id == u.id,
          where: cu.chat_id == ^chat_id,
          select: [:id, :username]
        )
      )

    users_proto = %Protobuf.Users{
      users:
        Enum.map(users, fn %User{id: id, username: username} ->
          %Protobuf.User{
            # Convert UUID to string
            id: Ecto.UUID.cast!(id),
            name: username
          }
        end)
    }

    {:ok, users_proto}
  end

  @doc """
  Inserts a new message into a specified chat.
  """
  def insert_chat_message(chat_id, user_id, content) do
    %ChatMessage{}
    |> ChatMessage.changeset(%{
      chat_id: chat_id,
      user_id: user_id,
      content: content,
      timestamp: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Fetches messages for a specific chat and returns them in Protobuf format.
  """
  def get_chat_messages(chat_id) do
    messages =
      Repo.all(
        from(m in ChatMessage,
          where: m.chat_id == ^chat_id,
          select: [:id, :user_id, :chat_id, :content, :timestamp],
          order_by: [desc: m.timestamp]
        )
      )

    messages_proto = %Protobuf.ChatMessages{
      messages:
        Enum.map(messages, fn %ChatMessage{
                                id: id,
                                user_id: user_id,
                                chat_id: chat_id,
                                content: content,
                                timestamp: timestamp
                              } ->
          %Protobuf.ChatMessage{
            # Ensure that the id is a string UUID
            id: Ecto.UUID.cast!(id),
            user_id: Ecto.UUID.cast!(user_id),
            chat_id: Ecto.UUID.cast!(chat_id),
            content: content,
            timestamp: DateTime.to_string(timestamp)
          }
        end)
    }

    {:ok, messages_proto}
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
end
