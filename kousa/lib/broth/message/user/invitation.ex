defmodule Broth.Message.User.Invitation do
  use Broth.Message.Push

  @primary_key false
  embedded_schema do
    field(:roomId, :binary_id)
    field(:name, :string)
    field(:fromUserId, :binary_id)
  end
end
