defmodule Broth.Message.Room.AuthUpdate do
  # NB: this is likely to be on the chopping block; will probably be replaced
  # by Phoenix.Tracker content.  DO NOT COPY/PASTE THIS CONTENT WITHOUT ASKING
  # FIRST

  use Broth.Message.Push,
    code: "room:auth_update"

  @derive {Jason.Encoder, only: [:userId, :level, :roomId]}

  embedded_schema do
    field(:userId, :binary_id)
    field(:level, Broth.Message.Types.RoomAuth)

    # LEGACY PURPOSES ONLY.  REMOVE AFTER v0.3.0
    field(:roomId, :binary_id)
  end
end
