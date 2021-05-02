defmodule Broth.Message.Room.Joined do
  # NB: this is likely to be on the chopping block; will probably be replaced
  # by Phoenix.Tracker content.  DO NOT COPY/PASTE THIS CONTENT WITHOUT ASKING
  # FIRST

  use Broth.Message.Push

  @derive {Jason.Encoder, only: [:user, :muteMap, :deafMap]}

  embedded_schema do
    embeds_one(:user, Beef.Schemas.User)
    field(:muteMap, :map)
    field(:deafMap, :map)
  end
end
