defmodule Broth.Message.Push do
  @moduledoc """
  API contract statement for push message modules
  """

  alias Broth.Message.Cast

  defmacro __using__(opts) do
    opcode =
      if opts[:code] do
        code_generator(opts[:code])
      end

    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @behaviour Broth.Message.Push

      Module.register_attribute(__MODULE__, :directions, accumulate: true, persist: true)
      @directions [:outbound]

      unquote(opcode)
      unquote(Cast.schema_ast(opts))

      @after_compile Broth.Message.Push
    end
  end

  @callback changeset(Broth.json()) :: Ecto.Changeset.t()
  @callback operation() :: String.t()

  @optional_callbacks [changeset: 1, operation: 0]

  defp code_generator(opcode) do
    quote do
      def code, do: unquote(opcode)
    end
  end

  def __after_compile__(%{module: module}, _bin) do
    # checks to make sure you've either declared a schema module, or you have
    # implemented a schema
    Cast.check_for_schema(module, :outbound)
  end
end
