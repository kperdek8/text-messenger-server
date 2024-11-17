defmodule TextMessengerServerWeb.NotificationChannel do
  use Phoenix.Channel

  def join("notifications:" <> user_id, _params, socket) do
    if user_id == socket.assigns.user_id do
      {:ok, socket}
    else
      {:error, "You are not this user"}
    end
  end

  def handle_info(%{event: "added_to_chat", payload: payload}, socket) do
    push(socket, "added_to_chat", payload)
    {:noreply, socket}
  end

  def handle_info(%{event: "removed_from_chat", payload: payload}, socket) do
    push(socket, "added_to_chat", payload)
    {:noreply, socket}
  end
end
