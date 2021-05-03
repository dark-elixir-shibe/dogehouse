defmodule Beef.Access.Rooms do
  import Ecto.Query
  @fetch_limit 16

  alias Beef.Queries.Rooms, as: Query
  alias Beef.Users
  alias Beef.UserBlocks
  alias Beef.Repo
  alias Beef.Schemas.User
  alias Beef.Schemas.Room
  alias Beef.Schemas.UserBlock
  alias Beef.Schemas.RoomBlock
  alias Beef.RoomPermissions
  alias Beef.RoomBlocks

  def get(room_id) do
    Query.start()
    |> Query.filter_by(id: room_id)
    |> Query.preload(:attendees)
    |> Repo.one()
  end

  def get_top_public_rooms(user_id, offset \\ 0) do
    max_room_size = Application.fetch_env!(:kousa, :max_room_size)

    items =
      from(r in Room,
        left_join: rb in RoomBlock,
        on: rb.roomId == r.id and rb.userId == ^user_id,
        left_join: ub in UserBlock,
        on: ub.userIdBlocked == ^user_id,
        where:
          is_nil(ub.userIdBlocked) and is_nil(rb.roomId) and r.isPrivate == false and
            r.numPeopleInside < ^max_room_size,
        order_by: [desc: r.numPeopleInside],
        offset: ^offset,
        limit: ^@fetch_limit
      )
      |> Repo.all()

    {Enum.slice(items, 0, -1 + @fetch_limit),
     if(length(items) == @fetch_limit, do: -1 + offset + @fetch_limit, else: nil)}
  end

  @user_order """
    (case
      when ? then 1
      else 2
    end)
  """
  @spec get_next_creator_for_room(any) :: any
  def get_next_creator_for_room(room_id) do
    from(u in User,
      inner_join: rp in Beef.Schemas.RoomPermission,
      on: rp.roomId == ^room_id and rp.userId == u.id and u.currentRoomId == ^room_id,
      where: rp.isSpeaker == true,
      limit: 1,
      order_by: [
        asc: fragment(@user_order, rp.isMod)
      ]
    )
    |> Repo.one()
  end

  def get_room_by_creator_id(creator_id) do
    Query.start()
    |> Query.filter_by(creatorId: creator_id)
    |> Repo.one()
  end

  # TODO: MAKE THIS A LENSE.
  def owner?(room_id, user_id) do
    not is_nil(
      Query.start()
      |> Query.filter_by(room_id: room_id, creatorId: user_id)
      |> Repo.one()
    )
  end

  def search_name(start_of_name) do
    search_str = start_of_name <> "%"

    Query.start()
    |> where([r], ilike(r.name, ^search_str) and r.isPrivate == false)
    |> limit([], 15)
    |> Repo.all()
  end

  @spec all_rooms :: any
  def all_rooms() do
    Repo.all(Room)
  end
end
