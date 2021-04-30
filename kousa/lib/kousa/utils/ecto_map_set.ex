# to be contributed back to Hex.pm once this is validated

defmodule EctoMapSet do
  use Ecto.ParameterizedType

  @impl true
  def type(opts), do: {:array, Keyword.fetch!(opts, :of)}

  @impl true
  def init(opts) do
    Enum.into(opts, %{})
  end

  @impl true
  def cast(data, _params) do
    {:ok, MapSet.new(data)}
  end

  @impl true
  def load(data, loader, _params) do
    {:ok, data
    |> Enum.map(loader)
    |> MapSet.new}
  end

  @impl true
  def dump(data, dumper, _params) do
    {:ok, Enum.map(data, dumper)}
  end

  @impl true
  def equal?(a, b, _params) do
    a == b
  end
end
