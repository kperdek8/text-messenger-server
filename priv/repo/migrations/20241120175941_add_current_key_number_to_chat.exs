defmodule TextMessengerServer.Repo.Migrations.AddCurrentKeyNumberToChat do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      add :current_key_number, :integer, default: 1, null: false
    end
  end
end
