defmodule Broth.Message.Room.RoleUpdate do
  # NB: this is likely to be on the chopping block; will probably be replaced
  # by Phoenix.Tracker content.  DO NOT COPY/PASTE THIS CONTENT WITHOUT ASKING
  # FIRST

  use Broth.Message.Push,
    code: "room:role_update"

  @derive {Jason.Encoder, only: [:userId, :role, :roomId]}
  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
    field(:role, Broth.Message.Types.RoomRole)

    # LEGACY PURPOSES ONLY.  REMOVE AFTER v0.3.0
    field(:roomId, :binary_id)
  end
end
