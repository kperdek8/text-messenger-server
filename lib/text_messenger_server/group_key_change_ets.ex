defmodule TextMessengerServer.GroupKeyChangeETS do
  @moduledoc """
  An ETS store to track whether a group key change is in progress.
  """

  @table_name :group_key_change_table

  # Starts ETS table for tracking key change state.
  def start_link(_) do
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}, {:write_concurrency, true}])
    :ok
  end

  # Check if a group key change is currently in progress for a given chat.
  def in_progress?(chat_id) do
    case :ets.lookup(@table_name, chat_id) do
      [{_chat_id, status}] -> status
      [] -> false
    end
  end

  # Set the status for whether a key change is in progress.
  def set_in_progress(chat_id, value) do
    :ets.insert(@table_name, {chat_id, value})
  end
end