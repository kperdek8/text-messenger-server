defmodule TextMessengerServer.GroupKeyChangeETS do
  use GenServer

  @moduledoc """
  A GenServer to initialize and manage an ETS table tracking group key change status.
  """

  @table_name :group_key_change_table

  def in_progress?(chat_id) do
    case :ets.lookup(@table_name, chat_id) do
      [{_chat_id, status}] -> status
      [] -> false
    end
  end

  def set_in_progress(chat_id, value) do
    :ets.insert(@table_name, {chat_id, value})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}, {:write_concurrency, false}])
    {:ok, %{}}
  end
end