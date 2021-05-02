defmodule Broth.Message.Room.Deafen do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:deafened, :boolean)
  end

  # inbound data.
  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:deafened])
    |> validate_required([:deafened])
  end

  def execute(changeset, state) do
    with {:ok, %{deafened: deafened?}} <- apply_action(changeset, :validation) do
      Onion.UserSession.set_deafen(state.user.id, deafened?)
      {:reply, %Empty{}, state}
    end
  end
end
