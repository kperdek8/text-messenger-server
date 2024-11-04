defmodule TextMessengerServerWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:" <> room_id, _params, socket) do
    {:ok, socket}
  end

  def handle_in("new_message", %{"content" => content, "user_id" => user_id}, socket) do
    broadcast!(socket, "new_message", %{content: content, user_id: user_id})
    IO.inspect(content)
    {:noreply, socket}
  end

  def handle_in("add_user", %{"user_id" => user_id}, socket) do
    broadcast!(socket, "add_user", %{user_id: user_id})
    {:noreply, socket}
  end
end
