defmodule TextMessengerServerWeb.UserSocket do
  use Phoenix.Socket

  alias TextMessengerServerWeb.Auth.Guardian

  channel "chat:*", TextMessengerServerWeb.ChatChannel
  channel "notifications:*", TextMessengerServerWeb.NotificationChannel

  def connect(%{"token" => token}, socket, _connect_info) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        user_id = Map.get(claims, "sub")
        {:ok, assign(socket, token: token, user_id: user_id)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end
