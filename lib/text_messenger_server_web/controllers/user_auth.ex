defmodule TextMessengerServerWeb.UserAuthController do
  use TextMessengerServerWeb, :controller
  alias TextMessengerServer.Accounts

  @placeholder_token "token123"

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
        conn
        |> put_status(:ok)
        |> json(%{message: "Login successful!", token: @placeholder_token, username: user.username, user_id: user.id})

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

  def verify_token(conn, %{"token" => token}) do
    if token == @placeholder_token do
      conn
      |> put_status(:ok)
      |> json(%{message: "Token valid"})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Token invalid"})
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
