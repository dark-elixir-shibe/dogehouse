defmodule Broth.Message.Room.Mute do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:muted, :boolean)
  end

  # inbound data.
  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:muted])
    |> validate_required([:muted])
  end

  def execute(changeset, state) do
    with {:ok, %{muted: muted?}} <- apply_action(changeset, :validation) do
      Onion.UserSession.set_mute(state.user.id, muted?)
      {:reply, %Empty{}, state}
    end
  end
end
