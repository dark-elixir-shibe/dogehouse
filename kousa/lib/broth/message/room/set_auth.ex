defmodule Broth.Message.Room.SetAuth do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
    field(:level, Broth.Message.Types.RoomAuth)
  end

  alias Kousa.Utils.UUID

  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:userId, :level])
    |> validate_required([:userId, :level])
    |> UUID.normalize(:userId)
  end

  def execute(changeset, state) do
    with {:ok, %{userId: user_id, level: level}} <- apply_action(changeset, :validate) do
      Kousa.Room.set_auth(user_id, level, by: state.user.id)
      {:reply, %Empty{}, state}
    end
  end
end
