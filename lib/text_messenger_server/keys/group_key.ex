defmodule TextMessengerServer.Chats.GroupKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "group_keys" do
    belongs_to :chat, TextMessengerServer.Chats.Chat, type: :binary_id
    belongs_to :user, TextMessengerServer.Accounts.User, type: :binary_id

    field :key_number, :integer
    field :encrypted_key, :binary

    timestamps()
  end

  @doc false
  def changeset(group_key, attrs) do
    group_key
    |> cast(attrs, [:chat_id, :user_id, :key_number, :encrypted_key])
    |> validate_required([:chat_id, :user_id, :key_number, :encrypted_key])
    |> unique_constraint([:chat_id, :user_id, :key_number]) # Ensures unique key per user-chat combination
  end
end