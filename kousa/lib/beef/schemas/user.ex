defmodule Beef.Schemas.User do
  use Ecto.Schema

  # the struct defined here can also be pushed to the user
  use Broth.Message.Push
  import Ecto.Changeset
  alias Beef.Schemas.Room

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          twitterId: String.t(),
          githubId: String.t(),
          discordId: String.t(),
          username: String.t(),
          email: String.t(),
          githubAccessToken: String.t(),
          discordAccessToken: String.t(),
          displayName: String.t(),
          avatarUrl: String.t(),
          bannerUrl: String.t(),
          bio: String.t(),
          reasonForBan: String.t(),
          ip: String.t(),
          tokenVersion: integer(),
          numFollowing: integer(),
          numFollowers: integer(),
          hasLoggedIn: boolean(),
          online: boolean(),
          lastOnline: DateTime.t(),
          youAreFollowing: boolean(),
          followsYou: boolean(),
          botOwnerId: nil | Ecto.UUID.t(),
          roomPermissions: nil | Beef.Schemas.RoomPermission.t(),
          currentRoomId: Ecto.UUID.t(),
          currentRoom: Room.t() | Ecto.Association.NotLoaded.t()
        }

  @derive {Jason.Encoder, only: ~w(id username avatarUrl bannerUrl bio online
    lastOnline currentRoomId displayName numFollowing numFollowers
    youAreFollowing followsYou botOwnerId roomPermissions)a}

  @primary_key {:id, :binary_id, []}
  schema "users" do
    field(:githubId, :string)
    field(:twitterId, :string)
    field(:discordId, :string)
    field(:username, :string)
    field(:email, :string)
    field(:githubAccessToken, :string)
    field(:discordAccessToken, :string)
    field(:displayName, :string)
    field(:avatarUrl, :string)
    field(:bannerUrl, :string)
    field(:bio, :string, default: "")
    field(:reasonForBan, :string)
    field(:tokenVersion, :integer)
    field(:numFollowing, :integer)
    field(:numFollowers, :integer)
    field(:hasLoggedIn, :boolean)
    field(:online, :boolean)
    field(:lastOnline, :utc_datetime_usec)
    field(:youAreFollowing, :boolean, virtual: true)
    field(:followsYou, :boolean, virtual: true)
    field(:roomPermissions, :map, virtual: true, null: true)
    field(:muted, :boolean, virtual: true)
    field(:deafened, :boolean, virtual: true)
    field(:apiKey, :binary_id)
    field(:ip, :string, null: true)

    belongs_to(:botOwner, Beef.Schemas.User, foreign_key: :botOwnerId, type: :binary_id)
    belongs_to(:currentRoom, Room, foreign_key: :currentRoomId, type: :binary_id)

    many_to_many(:blocked_by, __MODULE__,
      join_through: "user_blocks",
      join_keys: [userIdBlocked: :id, userId: :id]
    )

    timestamps()
  end

  #############################################################################
  ## CHANGESETS

  @doc false
  def create_changeset(data, attrs) do
    # TODO: amend this to accept *either* githubId or twitterId and also
    # pipe edit_changeset into this puppy.
    data
    |> cast(attrs, ~w(username githubId avatarUrl bannerUrl)a)
    |> changeset
  end

  def join_room_changeset(data, room_id) do
    data
    |> change(%{currentRoomId: room_id})
    |> changeset
  end

  def changeset(data, attrs \\ %{}) do
    data
    |> change
    |> validate_required([:username, :displayName, :avatarUrl])
    |> update_change(:displayName, &String.trim/1)
    |> validate_length(:bio, min: 0, max: 160)
    |> validate_length(:displayName, min: 2, max: 50)
    |> validate_format(:username, ~r/^[\w\.]{4,15}$/)
    |> validate_format(
      :avatarUrl,
      ~r/^https?:\/\/(www\.|)((a|p)bs.twimg.com\/(profile_images|sticky\/default_profile_images)\/(.*)\.(jpg|png|jpeg|webp)|avatars\.githubusercontent\.com\/u\/|github.com\/identicons\/[^\s]+)/
    )
    |> validate_format(
      :bannerUrl,
      ~r/^https?:\/\/(www\.|)(pbs.twimg.com\/profile_banners\/(.+)\/(.+)\/(.+)(?:\.(jpg|png|jpeg|webp))?|avatars\.githubusercontent\.com\/u\/)/
    )
    |> unique_constraint(:username)
  end
end
