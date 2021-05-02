defmodule Broth.Message.Room.Create do
  alias Beef.Schemas.Room

  use Broth.Message.Call,
    schema: Room,
    reply: Room

  def initialize(state) do
    change(%Room{}, creatorId: state.user.id)
  end

  defdelegate changeset(initializer, data), to: Beef.Schemas.Room, as: :create_changeset

  def execute(changeset, state) do
    case Kousa.Room.create_with(changeset, state.user) do
      {:ok, room, user} ->
        {:reply, room, %{state | user: user}}

      error ->
        error
    end
  end
end
