defmodule TextMessengerServer.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))
      add(:chat_id, references(:chats, type: :binary_id, on_delete: :delete_all))
      add(:content, :binary, null: false)
      add(:timestamp, :utc_datetime, null: false)

      timestamps()
    end

    create(index(:chat_messages, [:user_id]))
    create(index(:chat_messages, [:chat_id]))
  end
end
