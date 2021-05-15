defmodule Broth.Message.Room.Invited do
  use Broth.Message.Push,
    code: "room:invited"

  @derive {Jason.Encoder, only: [:roomId]}
  @primary_key false
  embedded_schema do
    field(:roomId, :binary_id)
    field(:name, :string)
    field(:fromUserId, :binary_id)
  end
end
