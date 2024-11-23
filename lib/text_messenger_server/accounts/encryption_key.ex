defmodule TextMessengerServer.Accounts.EncryptionKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "encryption_public_keys" do
    belongs_to :user, TextMessengerServer.Accounts.User, type: :binary_id

    field :public_key, :binary

    timestamps()
  end

  @doc false
  def changeset(encryption_public_key, attrs) do
    encryption_public_key
    |> cast(attrs, [:user_id, :public_key])
    |> validate_required([:user_id, :public_key])
    |> unique_constraint(:user_id)
  end
end