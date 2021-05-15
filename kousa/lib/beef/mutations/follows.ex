defmodule Beef.Mutations.Follows do
  import Ecto.Query

  alias Beef.Repo
  alias Beef.Schemas.Follow

  def follow(%{id: user_id}, target_id), do: follow(user_id, target_id)
  def follow(user_id, target_id) do
    %Follow{}
    |> Follow.insert_changeset(%{
      userId: target_id,
      followerId: user_id
    })
    |> Repo.insert
  end

  def unfollow(%{id: user_id}, target_id), do: unfollow(user_id, target_id)
  def unfollow(user_id, target_id) do
    query = from f in Follow,
      where: f.userId == ^target_id and f.followerId == ^user_id
    Repo.delete_all(query)
  end

end
