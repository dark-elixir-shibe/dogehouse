defmodule Broth.Message.Room.Invite do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
  end

  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:userId])
    |> validate_required([:userId])
  end

  def execute(data, state) do
    case apply_action(data, :validate) do
      {:ok, invite} ->
        Kousa.Room.invite_to_room(state.user.id, invite.userId)
        {:reply, %Empty{}, state}

      error = {:error, _} ->
        error
    end
  end
end
