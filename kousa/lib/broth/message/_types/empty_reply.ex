defmodule Broth.Message.Types.Empty do
  @doc """
  A generic empty reply for calls that only acknowledge
  successful receipt.
  """

  use Broth.Message.Push

  @derive {Jason.Encoder, only: []}
  @primary_key false
  embedded_schema do
  end
end
