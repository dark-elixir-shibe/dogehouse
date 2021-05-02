defmodule Broth.Message.Room.Leave do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    schema: Empty,
    reply: Empty

  def changeset(initializer \\ %Empty{}, data) do
    change(initializer, data)
  end

  def execute(_, state) do
    case Kousa.Room.leave_room(state.user.id) do
      {:ok, _} ->
        {:reply, %Empty{}, state}

      _ ->
        {:noreply, state}
    end
  end
end
