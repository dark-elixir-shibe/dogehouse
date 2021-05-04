defmodule Beef.Schemas.RoomPermission do
  use Ecto.Schema
  import Ecto.Changeset
  alias Beef.Schemas.Room

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          roomId: Ecto.UUID.t(),
          userId: Ecto.UUID.t(),
          isSpeaker: boolean(),
          isMod: boolean(),
          askedToSpeak: boolean()
        }

  alias Beef.Schemas.User

  @derive {Jason.Encoder, only: [:isSpeaker, :isMod, :askedToSpeak]}
  @primary_key false
  schema "room_permissions" do
    # NB THIS WILL BE CHANGED TO HAVE TWO ENUMS:
    # :auth -> :owner, :mod, :guest, :anon
    # :role -> :speaker, :hand_raised, :listener

    belongs_to(:user, User, foreign_key: :userId, type: :binary_id, primary_key: true)
    belongs_to(:room, Room, foreign_key: :roomId, type: :binary_id, primary_key: true)
    field(:isSpeaker, :boolean, default: false)
    field(:isMod, :boolean, default: false)
    field(:askedToSpeak, :boolean, default: false)

    timestamps()
  end

  @fields ~w(userId roomId isSpeaker isMod askedToSpeak)a

  @doc false
  def insert_changeset(permissions, attrs) do
    permissions
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def update_changeset(permissions, attrs) do
    permissions
    |> cast(attrs, [:isSpeaker, :isMod, :askedToSpeak])
    |> validate_required(@fields)
  end
end
