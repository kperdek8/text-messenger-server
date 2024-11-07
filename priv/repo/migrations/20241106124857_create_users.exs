defmodule TextMessengerServer.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")
    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()"))
      add(:username, :string, null: false)
      add(:hashed_password, :string, null: false)

      timestamps()
    end

    create(unique_index(:users, [:username]))
  end
end
