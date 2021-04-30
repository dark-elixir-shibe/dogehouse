defmodule Broth.Message.Room.Create do

  alias Beef.Schemas.Room

  use Broth.Message.Call,
    schema: Room,
    reply: Room

  def initialize(state) do
    change(%Room{}, creatorId: state.user.id)
  end

  def changeset(initializer \\ %Room{}, data) do
    initializer
    |> cast(data, [
      :name,
      :description,
      :isPrivate,
      :userIdsToInvite,
      :autoSpeaker,
      :scheduledRoomId
    ])
    |> validate_required([:name])
  end

  def execute(changeset, state) do
    changeset |> IO.inspect(label: "29")
    state |> IO.inspect(label: "30")
    case Kousa.Room.create_with(changeset, state.user) do
      {:ok, room} ->
        {:reply, room, %{state | room: room}}
      error -> error
    end
  end
end
