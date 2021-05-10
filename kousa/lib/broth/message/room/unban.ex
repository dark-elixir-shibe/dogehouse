defmodule Broth.Message.Room.Unban do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:userId, :binary_id)
  end

  alias Kousa.Utils.UUID

  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:userId])
    |> validate_required([:userId])
    |> UUID.normalize(:userId)
  end

  defmodule Reply do
    use Broth.Message.Push

    @derive {Jason.Encoder, only: []}

    @primary_key false
    embedded_schema do
    end
  end

  def execute(changeset, state) do
    with {:ok, %{userId: user_id}} <- apply_action(changeset, :validate) do
      Kousa.Room.unban(user_id, by: state.user)
      {:reply, %Empty{}, state}
    end
  end
end
