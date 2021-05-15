defmodule Broth.Message.User.Follow do
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

  def execute(changeset, state) do
    with {:ok, %{userId: user_id}} <- apply_action(changeset, :validate) do
      Kousa.User.follow(state.user, user_id)
      {:reply, %Empty{}, state}
    end
  end
end
