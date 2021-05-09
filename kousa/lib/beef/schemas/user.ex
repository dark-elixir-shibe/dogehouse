defmodule Beef.Schemas.User do
  use Ecto.Schema

  # the struct defined here can also be pushed to the user
  use Broth.Message.Push
  import Ecto.Changeset
  alias Beef.Schemas.Room
  alias Beef.Schemas.RoomPermission

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
          currentRoomId: nil | Ecto.UUID.t(),
          currentRoom: nil | Room.t()
        }

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

    field(:apiKey, :binary_id)

    # associations
    has_one(:roomPermissions, Beef.Schemas.RoomPermission,
      foreign_key: :userId,
      on_replace: :update
    )

    has_many(:bots, Beef.Schemas.User, foreign_key: :botOwnerId)
    belongs_to(:botOwner, Beef.Schemas.User, foreign_key: :botOwnerId, type: :binary_id)

    belongs_to(:currentRoom, Room, foreign_key: :currentRoomId, type: :binary_id)

    # THESE ARE ON THE CHOPPING BLOCK
    field(:youAreFollowing, :boolean, virtual: true)
    field(:followsYou, :boolean, virtual: true)
    field(:muted, :boolean, virtual: true)
    field(:deafened, :boolean, virtual: true)
    field(:ip, :string, null: true)

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
    |> cast(attrs, ~w(username githubId avatarUrl bannerUrl botOwnerId displayName apiKey bio)a)
    # TODO: merge into a common create method
    |> changeset
  end

  def join_room_changeset(data, room_id, permissions) do
    data
    |> change(%{currentRoomId: room_id})
    |> add_permissions(permissions)
    |> changeset
  end

  defp add_permissions(changeset, permissions) do
    changeset
    |> Map.put(:params, %{"roomPermissions" => permissions})
    |> cast_assoc(:roomPermissions, with: &RoomPermission.insert_changeset/2)
  end

  def change_perms(data, permissions) do
    data
    |> change
    |> Map.put(:params, %{"roomPermissions" => permissions})
    |> cast_assoc(:roomPermissions, with: &RoomPermission.update_changeset/2)
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

  defimpl Jason.Encoder do
    @fields ~w(id username avatarUrl bannerUrl bio online
    lastOnline currentRoomId displayName numFollowing numFollowers
    youAreFollowing followsYou botOwnerId roomPermission)a

    @impl true
    @spec encode(map, Jason.Encode.opts()) ::
            binary
            | maybe_improper_list(
                binary | maybe_improper_list(any, binary | []) | byte,
                binary | []
              )
    def encode(user, opts) do
      user
      |> Map.take(@fields)
      |> filter_valid_room_permissions
      |> Jason.Encoder.encode(opts)
    end

    defp filter_valid_room_permissions(user = %{roomPermissions: p})
         when is_nil(p) or is_struct(p, Ecto.Association.NotLoaded) do
      Map.delete(user, :roomPermissions)
    end

    defp filter_valid_room_permissions(user), do: user
  end
end
