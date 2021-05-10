defmodule Broth.Message.Chat.Unban do
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
    with {:ok, %{userId: userId}} <- apply_action(changeset, :validate) do
      # TODO: change to by: format
      Kousa.Chat.unban_user(userId, by: state.user)
      {:reply, %Empty{}, state}
    end
  end
end
