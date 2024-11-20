defmodule TextMessengerServer.Repo.Migrations.AddIvAndKeyNumberToChatMessage do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :iv, :binary, null: false
      add :key_number, :integer, null: false
    end
  end
end
