defmodule TextMessengerServerWeb.Router do
  use TextMessengerServerWeb, :router

  pipeline :api do
    plug(:accepts, ["json", "x-protobuf"])
  end

  scope "/api", TextMessengerServerWeb do
    pipe_through(:api)

    post("/users/register", UserAuthController, :register)
    post("/users/login", UserAuthController, :login)
    post("/verify_token", UserAuthController, :verify_token)
  end

  # Routes requiring JWT authentication
  scope "/api", TextMessengerServerWeb do
    pipe_through([:api, TextMessengerServerWeb.Auth.Pipeline])

    get("/users/:id", UserController, :fetch_user)
    get("/users", UserController, :fetch_users)

    get("/chats", ChatController, :fetch_chats)
    get("/chats/:id/messages", ChatMessagesController, :fetch_messages)  # Secured route
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:text_messenger_server, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: TextMessengerServerWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
