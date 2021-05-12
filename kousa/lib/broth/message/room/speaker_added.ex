defmodule Broth.Message.Room.SpeakerAdded do
  # NB: this is likely to be on the chopping block; will probably be replaced
  # by Phoenix.Tracker content.  DO NOT COPY/PASTE THIS CONTENT WITHOUT ASKING
  # FIRST

  alias EctoMapSet, as: MapSet

  use Broth.Message.Push,
    code: "room:speaking_update"

  @derive {Jason.Encoder, only: ~w(activeSpeakerMap muteMap deafMap roomId)a}
  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)

    # LEGACY PURPOSES ONLY.  REMOVE AFTER v0.3.0
    field(:muteMap, MapSet, of: :binary_id)
    field(:deafMap, MapSet, of: :binary_id)

    field(:roomId, :binary_id)
  end
end
