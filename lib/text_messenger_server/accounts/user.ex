defmodule TextMessengerServer.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:username, :string)
    # Used only for changeset and not stored
    field(:password, :string, virtual: true)
    field(:hashed_password, :string)

    timestamps()
  end

  @doc """
  Registration changeset for creating a user with password validation and hashing.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> unique_constraint(:username)
    |> validate_required([:username, :password])
    |> validate_length(:username, min: 3)
    |> validate_length(:password, min: 5)
    |> hash_password()
  end

  defp hash_password(changeset) do
    if password = get_change(changeset, :password) do
      put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end

  @doc """
  Changeset for validating username and password login attempts.
  """
  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
  end
end
