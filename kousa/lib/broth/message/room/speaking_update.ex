defmodule Broth.Message.Room.SpeakingUpdate do
  # NB: this is likely to be on the chopping block; will probably be replaced
  # by Phoenix.Tracker content.  DO NOT COPY/PASTE THIS CONTENT WITHOUT ASKING
  # FIRST

  alias EctoMapSet, as: MapSet

  use Broth.Message.Push,
    code: "room:speaking_update"

  @derive {Jason.Encoder, only: ~w(activeSpeakerMap muteMap deafMap roomId)a}
  @primary_key false
  embedded_schema do
    field(:activeSpeakerMap, MapSet, of: :binary_id)
    field(:muteMap, MapSet, of: :binary_id)
    field(:deafMap, MapSet, of: :binary_id)

    # LEGACY PURPOSES ONLY.  REMOVE AFTER v0.3.0
    field(:roomId, :binary_id)
  end
end
