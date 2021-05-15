defmodule Beef.Access.Follows do
  import Ecto.Query
  alias Beef.Repo
  alias Beef.Schemas.Follow

  # TODO: generalize these queries
  def follows?(user_id, target_id) do
    Repo.exists?(from f in Follow,
      where: f.userId == ^target_id and f.followerId == ^user_id)
  end
end
