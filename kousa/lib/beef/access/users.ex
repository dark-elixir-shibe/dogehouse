defmodule Beef.Access.Users do
  import Ecto.Query, warn: false

  alias Beef.Queries.Users, as: Query
  alias Beef.Repo
  alias Beef.Schemas.User
  alias Beef.Schemas.Room

  def get(user_id) do
    Query.start()
    |> Query.filter_by(id: user_id)
    |> Query.preload([:roomPermissions, :bots])
    |> Repo.one()
  end

  def find_by_github_ids(ids) do
    Query.start()
    |> Query.filter_by_github_ids(ids)
    |> Query.select_id()
    |> Repo.all()
  end

  def search_username(<<first_letter>> <> rest) when first_letter == ?@ do
    search_username(rest)
  end

  def search_username(start_of_username) do
    search_str = start_of_username <> "%"

    Query.start()
    |> where([u], ilike(u.username, ^search_str))
    |> limit([], 15)
    |> Repo.all()
  end

  @spec get_by_id_with_follow_info(any, any) :: any
  def get_by_id_with_follow_info(me_id, them_id) do
    Query.start()
    |> Query.filter_by_id(them_id)
    |> Query.follow_info(me_id)
    |> Query.limit_one()
    |> Repo.one()
  end

  def get_by_id(user_id) do
    Repo.get(User, user_id)
  end

  def get_by_id_with_room_permissions(user_id) do
    from(u in User,
      where: u.id == ^user_id,
      left_join: rp in Beef.Schemas.RoomPermission,
      on: rp.userId == u.id and rp.roomId == u.currentRoomId,
      select: %{u | roomPermissions: rp},
      limit: 1
    )
    |> Repo.one()
  end

  def get_by_username(username) do
    Query.start()
    |> Query.filter_by_username(username)
    |> Repo.one()
  end

  def get_by_username_with_follow_info(user_id, username) do
    Query.start()
    |> Query.filter_by_username(username)
    |> Query.follow_info(user_id)
    |> Repo.one()
  end

  @fetch_limit 16
  def search(query, offset) do
    query_with_percent = "%" <> query <> "%"

    items =
      from(u in User,
        where:
          ilike(u.username, ^query_with_percent) or
            ilike(u.displayName, ^query_with_percent),
        left_join: cr in Room,
        on: u.currentRoomId == cr.id and cr.isPrivate == false,
        select: %{u | currentRoom: cr},
        limit: @fetch_limit,
        offset: ^offset
      )
      |> Repo.all()

    {Enum.slice(items, 0, -1 + @fetch_limit),
     if(length(items) == @fetch_limit, do: -1 + offset + @fetch_limit, else: nil)}
  end

  @spec get_by_id_with_current_room(any) :: any
  def get_by_id_with_current_room(user_id) do
    from(u in User,
      left_join: a0 in assoc(u, :currentRoom),
      where: u.id == ^user_id,
      limit: 1,
      preload: [
        currentRoom: a0
      ]
    )
    |> Repo.one()
  end

  def get_by_api_key(api_key) do
    Repo.get_by(User, apiKey: api_key)
  end
end
