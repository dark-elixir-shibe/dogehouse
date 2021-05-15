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
    with {:ok, invite} <- apply_action(data, :validate),
         :ok <- Kousa.Room.invite(state.user, invite.userId) do
      {:reply, %Empty{}, state}
    end
  end
end
