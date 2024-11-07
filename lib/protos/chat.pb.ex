defmodule TextMessengerServer.Protobuf.User do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :name, 2, type: :string
end

defmodule TextMessengerServer.Protobuf.Users do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :users, 1, repeated: true, type: TextMessengerServer.Protobuf.User
end

defmodule TextMessengerServer.Protobuf.Chat do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :users, 2, repeated: true, type: TextMessengerServer.Protobuf.User
  field :name, 3, type: :string
end

defmodule TextMessengerServer.Protobuf.Chats do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :chats, 1, repeated: true, type: TextMessengerServer.Protobuf.Chat
end

defmodule TextMessengerServer.Protobuf.ChatMessage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :user_id, 2, type: :string, json_name: "userId"
  field :chat_id, 3, type: :string, json_name: "chatId"
  field :content, 4, type: :string
  field :timestamp, 5, type: :string
end

defmodule TextMessengerServer.Protobuf.ChatMessages do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :messages, 1, repeated: true, type: TextMessengerServer.Protobuf.ChatMessage
end