defmodule TextMessengerServerWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", TextMessengerServerWeb.ChatChannel
  channel "notifications:*", TextMessengerServerWeb.NotificationChannel

  # Replace with token verification later
  def connect(%{"user_id" => user_id}, socket, _connect_info) do
    {:ok, assign(socket, user_id: user_id)}
  end

  def connect(_params, _socket, _connect_info), do: :error

  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end
