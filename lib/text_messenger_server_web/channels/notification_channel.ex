defmodule TextMessengerServerWeb.NotificationChannel do
  use Phoenix.Channel

  def join("notifications:" <> user_id, _params, socket) do
    if user_id == socket.assigns.user_id do
      {:ok, socket}
    else
      {:error, "You are not this user"}
    end
  end
end
