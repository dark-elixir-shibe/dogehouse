defmodule Broth.Message.User.CreateBot do
  use Broth.Message.Call,
    reply: __MODULE__

  @derive {Jason.Encoder, only: [:username]}

  @primary_key {:id, :binary_id, []}
  schema "users" do
    field(:username, :string)
  end

  # inbound data.
  def changeset(initializer \\ %__MODULE__{}, data) do
    initializer
    |> cast(data, [:username])
    |> validate_required([:username])
  end

  defmodule Reply do
    use Broth.Message.Push

    @derive {Jason.Encoder, only: [:apiKey]}

    @primary_key false
    embedded_schema do
      field(:apiKey, :string)
    end
  end

  def execute(changeset!, state) do
    with {:ok, %{username: username}} <- apply_action(changeset!, :validation),
         {:ok, api_key, new_user} <- Kousa.User.create_bot(state.user, username) do
      {:reply, %Reply{apiKey: api_key}, %{state | user: new_user}}
    end
  end
end
