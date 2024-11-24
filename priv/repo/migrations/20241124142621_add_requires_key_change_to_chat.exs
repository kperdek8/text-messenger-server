defmodule TextMessengerServer.Repo.Migrations.AddRequiresKeyChangeToChat do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      add :requires_key_change, :boolean, default: false, null: false
    end
  end
end
