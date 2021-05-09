defmodule Broth.Message.User.Ban do
  alias Broth.Message.Types.Empty

  use Broth.Message.Call,
    reply: Empty

  @primary_key false
  embedded_schema do
    field(:userId, :binary)
    field(:reason, :string)
  end

  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:userId, :reason])
    |> validate_required([:userId, :reason])
  end

  def execute(changeset, state) do
    with {:ok, request} <- apply_action(changeset, :validate),
         :ok <- Kousa.User.ban(request.userId, request.reason, admin_id: state.user.id) do
      {:reply, %Empty{}, state}
    end
  end
end
