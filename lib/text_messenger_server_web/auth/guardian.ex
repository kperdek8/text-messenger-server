defmodule TextMessengerServerWeb.Auth.Guardian do
  use Guardian, otp_app: :text_messenger_server

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case TextMessengerServer.Accounts.get_user(id) do
      {:error, "User not found"} -> {:error, :no_resource_found}
      user -> {:ok, user}
    end
  end
end