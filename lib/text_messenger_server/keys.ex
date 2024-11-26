defmodule TextMessengerServer.Keys do
  alias TextMessengerServer.Repo
  alias TextMessengerServer.Accounts.{EncryptionKey, SignatureKey}
  alias TextMessengerServer.Chats.{Chat, ChatUser, GroupKey}
  alias TextMessengerServer.Protobuf

  import Ecto.Query

  @doc """
  Fetch encryption public keys of all users in a specific chat.
  """
  def get_encryption_keys_for_chat(chat_id) do
    keys = from(cu in ChatUser,
      join: ek in EncryptionKey,
      on: cu.user_id == ek.user_id,
      where: cu.chat_id == ^chat_id,
      select: ek,
      order_by: ek.user_id
    )
    |> Repo.all()
    |> to_protobuf_encryption_keys()
    {:ok, keys}
  end

  @doc """
  Fetch signature public keys of all users in a specific chat.
  """
  def get_signature_keys_for_chat(chat_id) do
    keys = from(cu in ChatUser,
      join: sk in SignatureKey,
      on: cu.user_id == sk.user_id,
      where: cu.chat_id == ^chat_id,
      select: sk,
      order_by: sk.user_id
    )
    |> Repo.all()
    |> to_protobuf_signature_keys()
    {:ok, keys}
  end

  @doc """
  Fetch the encryption public key for a specific user.
  """
  def get_encryption_key(user_id) do
    case Repo.get_by(EncryptionKey, user_id: user_id) do
      nil -> {:ok, nil}
      key -> {:ok, to_protobuf_encryption_key(key)}
    end
  end

  @doc """
  Fetch the signature public key for a specific user.
  """
  def get_signature_key(user_id) do
    case Repo.get_by(SignatureKey, user_id: user_id) do
      nil -> {:ok, nil}
      key -> {:ok, to_protobuf_signature_key(key)}
    end
  end

  @doc """
  Updates the encryption public key for a specific user.
  If no record exists, inserts a new one.
  """
  def change_encryption_key(user_id, new_public_key) do
    %EncryptionKey{}
    |> EncryptionKey.changeset(%{user_id: user_id, public_key: new_public_key})
    |> Repo.insert_or_update!(
      conflict_target: [:user_id],
      on_conflict: [set: [public_key: new_public_key, updated_at: DateTime.utc_now()]]
    )
    |> to_protobuf_encryption_key()
  end

  @doc """
  Updates the signature public key for a specific user.
  If no record exists, inserts a new one.
  """
  def change_signature_key(user_id, new_public_key) do
    %SignatureKey{}
    |> SignatureKey.changeset(%{user_id: user_id, public_key: new_public_key})
    |> Repo.insert_or_update!(
      conflict_target: [:user_id],
      on_conflict: [set: [public_key: new_public_key, updated_at: DateTime.utc_now()]]
    )
    |> to_protobuf_signature_key()
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
    |> to_protobuf_group_key()
  end

  @doc """
  Fetch all group keys for a specific chat and user, sorted by key_number.
  """
  def get_all_group_keys(chat_id, user_id) do
    keys = GroupKey
    |> where([gk], gk.chat_id == ^chat_id and gk.recipient_id == ^user_id)
    |> order_by([gk], asc: gk.key_number)  # Sort by key_number in ascending order
    |> Repo.all()
    |> IO.inspect()
    |> to_protobuf_group_keys()
    {:ok, keys}
  end

  # TODO: Separate check function to ensure that: creator_id is the same as request sender and signatures are valid.
  @doc """
  Changes group key by inserting it and incrementing key number.
  """
  def change_group_key(chat_id, %Protobuf.GroupKeys{group_keys: group_keys}) do
    Repo.transaction(fn ->
      # 1. Increment the group key number for the chat
      case increment_key_number(chat_id) do
        {:error, reason} ->
          # Rollback and return error if incrementing key number fails
          {:error, reason}
        {:ok, key_number} ->
          # 2. Insert the group keys into the database
          case insert_group_keys(chat_id, group_keys, key_number) do
            :ok ->
              # Return success if all group keys were inserted
              :group_keys_inserted
            {:error, reason} ->
              # Rollback and return error if insertion fails
              {:error, reason}
          end
      end
    end)
  end


  @doc """
  Validates that the number of provided group keys matches the number of chat members.
  """
  def validate_group_keys_count(chat_id, %Protobuf.GroupKeys{group_keys: group_keys}) do
    users_count = get_chat_users_count(chat_id)
    group_keys_count = length(group_keys)

    if group_keys_count != users_count do
      {:error, :key_member_count_mismatch}
    else
      :ok
    end
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
    from(c in Chat,
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
    Enum.each(group_keys, fn %Protobuf.GroupKey{recipient_id: recipient_id, creator_id: creator_id,
                                                encrypted_key: encrypted_key,signature: signature } ->
      case insert_group_key(chat_id, recipient_id, creator_id, encrypted_key, key_number, signature) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Insert a new group key into the database
  defp insert_group_key(chat_id, recipient_id, creator_id, encrypted_key, key_number, signature) do
    %GroupKey{}
    |> GroupKey.changeset(%{
      chat_id: chat_id,
      recipient_id: recipient_id,
      creator_id: creator_id,
      key_number: key_number,
      encrypted_key: encrypted_key,
      signature: signature
    })
    |> Repo.insert()
    |> case do
      {:ok, _group_key} -> :ok
      {:error, %{errors: errors}} -> {:error, "Failed to insert group key: #{inspect(errors)}"}
    end
  end

  # Conversion functions

  defp to_protobuf_encryption_key(%EncryptionKey{user_id: user_id, public_key: key}) do
    %Protobuf.EncryptionKey{
      user_id: user_id,
      public_key: key,
    }
  end

  defp to_protobuf_encryption_keys(keys) do
    %Protobuf.EncryptionKeys{
      encryption_keys: Enum.map(keys, &to_protobuf_encryption_key/1)
    }
  end

  defp to_protobuf_signature_key(%SignatureKey{user_id: user_id, public_key: key}) do
    %Protobuf.SignatureKey{
      user_id: user_id,
      public_key: key,
    }
  end

  defp to_protobuf_signature_keys(keys) do
    %Protobuf.SignatureKeys{
      signature_keys: Enum.map(keys, &to_protobuf_signature_key/1)
    }
  end

  defp to_protobuf_group_key(%GroupKey{chat_id: chat_id, recipient_id: recipient_id, creator_id: creator_id, key_number: key_number, encrypted_key: encrypted_key, signature: signature}) do
    %Protobuf.GroupKey{
      chat_id: chat_id,
      recipient_id: recipient_id,
      creator_id: creator_id,
      key_number: key_number,
      encrypted_key: encrypted_key,
      signature: signature
    }
  end

  defp to_protobuf_group_keys(keys) do
    %Protobuf.GroupKeys{
      group_keys: Enum.map(keys, &to_protobuf_group_key/1)
    }
  end
end