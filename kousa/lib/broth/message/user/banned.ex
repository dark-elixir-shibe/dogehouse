defmodule Broth.Message.User.Banned do
  use Broth.Message.Push,
    code: "user:banned"

  @derive {Jason.Encoder, only: []}
  @primary_key false
  embedded_schema do end
end
