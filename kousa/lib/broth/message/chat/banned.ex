defmodule Broth.Message.Chat.Banned do
  use Broth.Message.Push,
    code: "chat:banned"

  @derive {Jason.Encoder, only: [:userId]}
  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
  end
end
