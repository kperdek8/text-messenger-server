defmodule TextMessengerServer.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  # UUID v4 primary key
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "chats" do
    field(:name, :string)
    field :current_key_number, :integer, default: 1
    field :requires_key_change, :boolean, default: false

    many_to_many(:users, TextMessengerServer.Accounts.User, join_through: "chat_users")

    has_many :group_keys, TextMessengerServer.Chats.GroupKey

    timestamps()
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:name, :current_key_number, :requires_key_change])
    |> validate_required([:name, :current_key_number])
  end
end
