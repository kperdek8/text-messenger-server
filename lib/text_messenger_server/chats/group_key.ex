defmodule TextMessengerServer.Chats.GroupKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "group_keys" do
    belongs_to :chat, TextMessengerServer.Chats.Chat, type: :binary_id
    belongs_to :recipient, TextMessengerServer.Accounts.User, type: :binary_id
    belongs_to :creator, TextMessengerServer.Accounts.User, type: :binary_id

    field :key_number, :integer
    field :encrypted_key, :binary
    field :signature, :binary

    timestamps()
  end

  @doc false
  def changeset(group_key, attrs) do
    group_key
    |> cast(attrs, [:chat_id, :recipient_id, :creator_id, :key_number, :encrypted_key, :signature])
    |> validate_required([:chat_id, :recipient_id, :creator_id, :key_number, :encrypted_key, :signature])
    |> unique_constraint([:chat_id, :recipient_id, :key_number]) # Ensures unique key per recipient-chat combination
  end
end