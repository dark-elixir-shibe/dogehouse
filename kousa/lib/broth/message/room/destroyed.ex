defmodule Broth.Message.Room.Destroyed do
  use Broth.Message.Push,
    code: "room:destroyed"

  @derive {Jason.Encoder, only: [:roomId]}
  @primary_key false
  embedded_schema do
    field(:roomId, :binary_id)
  end
end
