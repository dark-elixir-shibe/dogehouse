defmodule Broth.Message.Chat.Ban do
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
      Kousa.Chat.ban_user(userId, by: state.user)
      {:reply, %Empty{}, state}
    end
  end
end
