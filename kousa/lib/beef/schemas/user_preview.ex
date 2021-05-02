defmodule Beef.Schemas.UserPreview do
  @moduledoc """
  a shorter version of User for display purposes only.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, []}
  schema "users" do
    field(:avatarUrl, :string)
    field(:displayName, :string)
    field(:bio, :string, default: "")
    field(:currentRoomId, :binary_id)

    # TO BE DEPRECATED IN FAVOR OF HAVING THE ENTIRE
    # FOLLOWS LIST/FOLLOWERS LIST.
    field(:numFollowers, :integer)

    # TODO add follows/following associations here.
  end
end
