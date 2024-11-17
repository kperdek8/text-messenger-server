defmodule TextMessengerServerWeb.UserAuthController do
  use TextMessengerServerWeb, :controller
  alias TextMessengerServer.Accounts

  def register(conn, %{"username" => username, "password" => password}) do
    case Accounts.register_user(%{username: username, password: password}) do
      {:ok, _user} ->
        conn
        |> put_status(:created)
        |> json(%{message: "Registration successful!", username: username})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "registration_failed",
          details: translate_changeset_errors(changeset)
        })
    end
  end

  def login(conn, %{"username" => username, "password" => password}) do
    case Accounts.authenticate_user(username, password) do
      {:ok, user} ->
        claims = %{
          "sub" => user.id,
          "exp" => DateTime.utc_now() |> DateTime.add(24 * 60 * 60, :second) |> DateTime.to_unix(:seconds),
          "username" => user.username
        }
        {:ok, token, _claims} = TextMessengerServerWeb.Auth.Guardian.encode_and_sign(user, claims)
        conn
        |> put_status(:ok)
        |> json(%{message: "Login successful!", token: token, username: user.username, user_id: user.id})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid password"})
    end
  end

  # Helper function to translate and format changeset errors
  defp translate_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
