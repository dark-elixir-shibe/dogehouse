defmodule Broth.Message.Room.Banned do
  use Broth.Message.Push,
    code: "room:banned"

  @derive {Jason.Encoder, only: [:roomId]}
  @primary_key false
  embedded_schema do
    field(:roomId, :binary_id)
  end
end
