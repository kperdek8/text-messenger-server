defmodule TextMessengerServer.Repo.Migrations.CreateEncryptionKeys do
  use Ecto.Migration

  def change do
    create table(:encryption_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :public_key, :binary, null: false

      timestamps()
    end

    create unique_index(:encryption_keys, [:user_id], name: :unique_encryption_key_per_user)
  end
end
