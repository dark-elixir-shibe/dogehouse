defmodule Broth.Message.Room.Join do
  use Broth.Message.Call,
    reply: Beef.Schemas.Room

  @primary_key false
  embedded_schema do
    field(:roomId, :binary_id)
  end

  alias Kousa.Utils.UUID

  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:roomId])
    |> validate_required([:roomId])
    |> UUID.normalize(:roomId)
  end

  def execute(changeset, state) do
    with {:ok, %{roomId: room_id}} <- apply_action(changeset, :validate) |> IO.inspect(label: "20"),
         {:ok, room} <- Kousa.Room.join(room_id, state.user.id) |> IO.inspect(label: "21") do

      {:reply, room, %{state | room: room}}
    end
  end
end
