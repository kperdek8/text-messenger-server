defmodule TextMessengerServerWeb.UserController do
  use TextMessengerServerWeb, :controller

  alias User
  alias Users

  @users [
    %User{
      id: 1,
      name: "user1"
    },
    %User{
      id: 2,
      name: "user2"
    }
  ]

  def fetch_users(conn, _params) do
    user_list = %Users{users: @users}

    conn
    |> put_resp_content_type("application/x-protobuf")
    |> send_resp(200, Users.encode(user_list))
  end

  def fetch_user(conn, %{"id" => id}) do
    user =
      @users
      |> Enum.find(fn %User{id: user_id} -> user_id == String.to_integer(id) end)

    if user do
      conn
      |> put_resp_content_type("application/x-protobuf")
      |> send_resp(200, User.encode(user))
    else
      conn
      |> send_resp(404, "User not found")
    end
  end
end
