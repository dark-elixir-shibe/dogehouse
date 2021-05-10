defmodule Broth.Message.Chat.Unbanned do
  use Broth.Message.Push,
    code: "chat:unbanned"

  @derive {Jason.Encoder, only: [:userId]}
  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
  end
end
