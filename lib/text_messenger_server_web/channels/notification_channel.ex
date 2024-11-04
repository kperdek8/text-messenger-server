defmodule TextMessengerServerWeb.NotificationChannel do
  use Phoenix.Channel

  def join("notifications:" <> user_id, _params, socket) do
    {:ok, socket}
  end
end
