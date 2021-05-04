defmodule Broth.Message.Room.SetRole do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
    field(:role, Broth.Message.Types.RoomRole)
  end

  alias Kousa.Utils.UUID

  def initialize(state) do
    # TODO: obtain the initial state of this first prior to changing it.
    %__MODULE__{userId: state.user.id}
  end

  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:userId, :role])
    # if we don't have an id, assume self.
    |> validate_required([:userId, :role])
  end

  def execute(changeset, state = %{user: owner}) do
    with {:ok, %{userId: user_id, role: role}} <- apply_action(changeset, :validate),
         :ok <- Kousa.Room.set_role(owner.currentRoomId, user_id, to: role, by: state.user) do
      {:reply, %Empty{}, state}
    end
  end
end
