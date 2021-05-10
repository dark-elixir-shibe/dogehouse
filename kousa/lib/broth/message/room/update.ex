defmodule Broth.Message.Room.Update do
  use Broth.Message.Call,
    reply: __MODULE__

  # temporary feature.
  def code, do: "room:update"

  @derive {Jason.Encoder, only: [:name, :description, :isPrivate, :autoSpeaker]}

  @primary_key {:id, :binary_id, []}
  schema "rooms" do
    field(:name, :string)
    field(:description, :string, default: "")
    field(:isPrivate, :boolean)
    field(:autoSpeaker, :boolean, virtual: true)
  end

  def initialize(state) do
    if room = Beef.Rooms.get_room_by_creator_id(state.user.id) do
      struct(__MODULE__, Map.from_struct(room))
    end
  end

  def changeset(initializer \\ %__MODULE__{}, data)

  def changeset(nil, _) do
    %__MODULE__{}
    |> change
    # generally 404 on an auth error
    |> add_error(:id, "does not exist")
  end

  def changeset(initializer, data) do
    initializer
    |> cast(data, ~w(description isPrivate name autoSpeaker)a)
    |> validate_required([:name])
  end

  def execute(
        changeset,
        state = %{user: %{id: owner_id, currentRoom: %{id: room_id, creatorId: owner_id}}}
      ) do
    case Kousa.Room.update(room_id, changeset) do
      {:ok, update} ->
        new_user = %{state.user | currentRoom: update}
        {:reply, struct(__MODULE__, Map.from_struct(update)), %{state | user: new_user}}

      error ->
        error
    end
  end

  def execute(_, _), do: {:error, "permission denied"}
end
