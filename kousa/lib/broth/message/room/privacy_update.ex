defmodule Broth.Message.Room.PrivacyUpdate do
  # NB: this is likely to be on the chopping block; will probably be replaced
  # by Phoenix.Tracker content.  DO NOT COPY/PASTE THIS CONTENT WITHOUT ASKING
  # FIRST

  use Broth.Message.Push,
    code: "room:privacy_update"

  @derive {Jason.Encoder, only: ~w(isPrivate name roomId)a}
  @primary_key false
  embedded_schema do
    field(:isPrivate, :boolean)
    # LEGACY PURPOSES ONLY.  REMOVE AFTER v0.3.0
    field(:name, :string)
    field(:roomId, :binary_id)
  end
end
