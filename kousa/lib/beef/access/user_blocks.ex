defmodule Beef.Access.UserBlocks do
  @moduledoc """
    DB Access Functions for UserBlocks Table
  """

  # alias Beef.Schemas.UserBlock
  alias Beef.Repo
  alias Beef.Queries.UserBlocks, as: Query

  def blocked?(user_id, target_id) do
    not is_nil(
      Query.start()
      |> Query.filter_by_id_and_blockedId(user_id, target_id)
      |> Repo.one()
    )
  end
end
