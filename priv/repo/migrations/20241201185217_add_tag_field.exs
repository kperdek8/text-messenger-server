defmodule TextMessengerServer.Repo.Migrations.AddTagField do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :tag, :binary, null: false
    end
  end
end
