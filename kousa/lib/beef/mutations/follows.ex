defmodule Beef.Mutations.Follows do
  import Ecto.Query

  alias Beef.Repo
  alias Beef.Schemas.Follow

  def follow(%{id: user_id}, target_id), do: follow(user_id, target_id)
  def follow(user_id, target_id) do
    %Follow{}
    |> Follow.insert_changeset(%{
      userId: user_id,
      followerId: target_id
    })
    |> Repo.insert
  end

  def follow(%{id: user_id}, target_id), do: unfollow(user_id, target_id)
  def unfollow(user_id, target_id) do
    query = from f in Follow,
      where: f.user_id == ^user_id and f.followerId == ^target_id
    Repo.delete_all(query)
  end

end
