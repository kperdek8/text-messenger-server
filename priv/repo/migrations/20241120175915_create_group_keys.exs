defmodule TextMessengerServer.Repo.Migrations.CreateGroupKeys do
  use Ecto.Migration

  def change do
    create table(:group_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :chat_id, references(:chats, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :creator_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :key_number, :integer, null: false
      add :encrypted_key, :binary, null: false
      add :signature, :binary, null: false

      timestamps()
    end

    create unique_index(:group_keys, [:chat_id, :recipient_id, :key_number], name: :unique_group_key_per_user_and_number)
  end
end