defmodule Beef.Schemas.Room do
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  use Broth.Message.Push

  alias Beef.Schemas.User

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t(),
          numPeopleInside: integer(),
          isPrivate: boolean(),
          user: User.t(),
          attendees: [User.t()]
        }

  @derive {Jason.Encoder, only: ~w(id name description numPeopleInside isPrivate
           creatorId peoplePreviewList voiceServerId inserted_at)a}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "rooms" do
    field(:name, :string)
    field(:description, :string, default: "")
    field(:numPeopleInside, :integer)
    field(:isPrivate, :boolean)
    field(:voiceServerId, :string)
    field(:autoSpeaker, :boolean, virtual: true)

    # TODO: change this to owner!
    belongs_to(:user, User, foreign_key: :creatorId, type: :binary_id)
    has_many(:attendees, User, foreign_key: :currentRoomId)

    field(:userIdsToInvite, {:array, :binary_id}, virtual: true, default: [])
    field(:scheduledRoomId, :binary_id, virtual: true)

    timestamps()
  end

  @spec insert_changeset(
          {map, map} | %{:__struct__ => atom | %{__changeset__: map}, optional(atom) => any},
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  @doc false
  def insert_changeset(room, attrs) do
    room
    |> cast(attrs, [
      :id,
      :name,
      :creatorId,
      :isPrivate,
      :numPeopleInside,
      :voiceServerId,
      :description
    ])
    |> validate_required([:name, :creatorId])
    |> validate_length(:name, min: 2, max: 60)
    |> validate_length(:description, max: 500)
    |> unique_constraint(:creatorId)
  end

  @spec edit_changeset(
          {map, map} | %{:__struct__ => atom | %{__changeset__: map}, optional(atom) => any},
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def edit_changeset(room, attrs) do
    room
    |> cast(attrs, [:id, :name, :isPrivate, :description])
    |> validate_length(:name, min: 2, max: 60)
    |> validate_length(:description, max: 500)
  end
end
