defmodule TextMessengerServerWeb.KeyController do
  use TextMessengerServerWeb, :controller

  alias TextMessengerServer.Chats
  alias TextMessengerServer.Keys
  alias TextMessengerServer.Protobuf.{User, GroupKeys, GroupKey, UserKeys, UserKeysList, EncryptionKey, SignatureKey, EncryptionKeys, SignatureKeys}

  def post_encryption_key(conn, %{"key" => base64_key}) do
    case Base.decode64(base64_key) do
      {:ok, binary_key} ->
        {:ok, %User{id: user_id}} = Guardian.Plug.current_resource(conn)

        encryption_key = Keys.change_encryption_key(user_id, binary_key)
        conn
        |> put_resp_content_type("application/x-protobuf")
        |> send_resp(200, EncryptionKey.encode(encryption_key))

      :error ->
        conn
        |> send_resp(400, Jason.encode!(%{error: "Invalid Base64 encoding"}))
    end
  end

  def post_signature_key(conn, %{"key" => base64_key}) do
    case Base.decode64(base64_key) do
      {:ok, binary_key} ->
        {:ok, %User{id: user_id}} = Guardian.Plug.current_resource(conn)

        signature_key = Keys.change_signature_key(user_id, binary_key)
        conn
        |> put_resp_content_type("application/x-protobuf")
        |> send_resp(200, SignatureKey.encode(signature_key))

      :error ->
        conn
        |> send_resp(400, Jason.encode!(%{error: "Invalid Base64 encoding"}))
    end
  end

  def fetch_user_keys(conn, %{"id" => user_id}) do
    {:ok, encryption_key} = Keys.get_encryption_key(user_id)
    {:ok, signature_key} = Keys.get_signature_key(user_id)

    user_keys = %UserKeys{
      user_id: user_id,
      encryption_key: encryption_key && encryption_key.public_key, # Set to nil if key doesn't exist
      signature_key: signature_key && signature_key.public_key # Set to nil if key doesn't exist
    }

    # Send response
    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, UserKeys.encode(user_keys))
  end

  def fetch_members_public_keys(conn, %{"id" => chat_id}) do
    {:ok, %User{id: user_id}} = Guardian.Plug.current_resource(conn)

    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      with {:ok, %EncryptionKeys{encryption_keys: encryption_keys}} <- Keys.get_encryption_keys_for_chat(chat_id),
           {:ok, %SignatureKeys{signature_keys: signature_keys}} <- Keys.get_signature_keys_for_chat(chat_id) do

        encryption_keys_map = Map.new(encryption_keys, &{&1.user_id, &1.public_key})
        signature_keys_map = Map.new(signature_keys, &{&1.user_id, &1.public_key})

        # Combine into UserKeys structs
        user_keys_list = %UserKeysList{user_keys:
          Map.merge(encryption_keys_map, signature_keys_map)
          |> Map.keys()
          |> Enum.map(fn user_id ->
            %UserKeys{
              user_id: user_id,
              encryption_key: Map.get(encryption_keys_map, user_id),
              signature_key: Map.get(signature_keys_map, user_id)
            }
          end)
        }

        conn
        |> put_resp_content_type("application/x-protobuf")
        |> send_resp(200, UserKeysList.encode(user_keys_list))
      else
        {:error, _reason} ->
          conn
          |> send_resp(500, Jason.encode!(%{error: "Internal server error"}))
      end
    else
      conn
      |> send_resp(403, Jason.encode!(%{error: "You are not member of this chat"}))
    end
  end

  def fetch_latest_group_key(conn, %{"id" => chat_id}) do
    {:ok, %User{id: user_id}} = Guardian.Plug.current_resource(conn)
    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      {:ok, key} = Keys.get_latest_group_key(chat_id, user_id)

      conn
      |> put_resp_content_type("application/x-protobuf")
      |> send_resp(200, GroupKey.encode(key))
    else
      conn
      |> send_resp(403, Jason.encode!(%{error: "You are not member of this chat"}))
    end
  end

  def fetch_group_keys(conn, %{"id" => chat_id}) do
    {:ok, %User{id: user_id}} = Guardian.Plug.current_resource(conn)
    if Chats.is_user_member_of_chat?(user_id, chat_id) do
      {:ok, keys} = Keys.get_all_group_keys(chat_id, user_id)

      conn
      |> put_resp_content_type("application/x-protobuf")
      |> send_resp(200, GroupKeys.encode(keys))
    else
      conn
      |> send_resp(403, Jason.encode!(%{error: "You are not member of this chat"}))
    end
  end
end