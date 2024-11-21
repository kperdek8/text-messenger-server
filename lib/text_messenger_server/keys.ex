defmodule TextMessengerServer.Keys do
  alias TextMessengerServer.Repo
  alias TextMessengerServer.Accounts.{EncryptionPublicKey, SignaturePublicKey}
  alias TextMessengerServer.Chats.{Chat, ChatUser, GroupKey}
  alias TextMessengerServer.Protobuf

  import Ecto.Query

  @doc """
  Fetch encryption public keys of all users in a specific chat.
  """
  def get_encryption_public_keys_for_chat(chat_id) do
    from(cu in ChatUser,
      join: epk in EncryptionPublicKey,
      on: cu.user_id == epk.user_id,
      where: cu.chat_id == ^chat_id,
      select: %{user_id: epk.user_id, public_key: epk.public_key}
    )
    |> Repo.all()
  end

  @doc """
  Fetch signature public keys of all users in a specific chat.
  """
  def get_signature_public_keys_for_chat(chat_id) do
    from(cu in ChatUser,
      join: spk in SignaturePublicKey,
      on: cu.user_id == spk.user_id,
      where: cu.chat_id == ^chat_id,
      select: %{user_id: spk.user_id, public_key: spk.public_key}
    )
    |> Repo.all()
  end

  @doc """
  Fetch the encryption public key for a specific user.
  """
  def get_encryption_public_key(user_id) do
    EncryptionPublicKey
    |> Repo.get_by(user_id: user_id)
  end

  @doc """
  Fetch the signature public key for a specific user.
  """
  def get_signature_public_key(user_id) do
    SignaturePublicKey
    |> Repo.get_by(user_id: user_id)
  end

  @doc """
  Updates the encryption public key for a specific user.
  If no record exists, inserts a new one.
  """
  def change_encryption_public_key(user_id, new_public_key) do
    %EncryptionPublicKey{}
    |> EncryptionPublicKey.changeset(%{user_id: user_id, public_key: new_public_key})
    |> Repo.insert_or_update(
      conflict_target: [:user_id],
      on_conflict: [set: [public_key: new_public_key, updated_at: DateTime.utc_now()]]
    )
  end

  @doc """
  Updates the signature public key for a specific user.
  If no record exists, inserts a new one.
  """
  def change_signature_public_key(user_id, new_public_key) do
    %SignaturePublicKey{}
    |> SignaturePublicKey.changeset(%{user_id: user_id, public_key: new_public_key})
    |> Repo.insert_or_update(
      conflict_target: [:user_id],
      on_conflict: [set: [public_key: new_public_key, updated_at: DateTime.utc_now()]]
    )
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
end