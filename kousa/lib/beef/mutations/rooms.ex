defmodule Beef.Mutations.Rooms do
  import Ecto.Query

  alias Beef.Repo
  alias Beef.Schemas.Room
  alias Beef.Users
  alias Beef.Schemas.User

  def replace_owner(room, user_id) do
    room
    |> Room.change_owner(%{creatorId: user_id})
    |> Repo.update()
  end

  def set_room_privacy_by_creator_id(user_id, isPrivate, new_name) do
    from(r in Room,
      where: r.creatorId == ^user_id,
      update: [
        set: [
          isPrivate: ^isPrivate,
          name: ^new_name
        ]
      ],
      select: r
    )
    |> Repo.update_all([])
  end

  def delete_room_by_id(room_id) do
    %Room{id: room_id} |> Repo.delete()
  end

  # trusts that the user is in the room
  def kick_from_room(user_id, room_id) do
    room = Beef.Rooms.get(room_id)
    Beef.Users.set_user_left_current_room(user_id)
    new_people_list = Enum.filter(room.peoplePreviewList, fn x -> x.id != user_id end)
  end

  def leave_room(user_id, room_id) do
    case Beef.Rooms.get(room_id) do
      room = %{attendees: [%{id: ^user_id}]} ->
        delete_room_by_id(room_id)
        {:deleted, room}
      room = %{creatorId: ^user_id} ->
        # replace this as a lens:
        new_creator_id = Beef.Rooms.get_next_creator_for_room(room_id)

        # jesus christ.
        Beef.Users.set_user_left_current_room(user_id)

        room
        |> Room.change_owner(%{creatorId: new_creator_id})
        |> Repo.update
      room ->
        if Enum.any?(room.attendees, &(&1.id == user_id)) do
          Beef.Users.set_user_left_current_room(user_id)
        end
        {:ok, %{room | attendees: Enum.reject(room.attendees, &(&1.id == user_id))}}
    end
  end

  def update_name(user_id, name) do
    from(r in Room,
      where: r.creatorId == ^user_id,
      update: [
        set: [
          name: ^name
        ]
      ]
    )
    |> Repo.update_all([])
  end

  @spec create(:invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}) :: any
  def create(data) do
    raise "wtf"

    user = Beef.Users.get_by_id(data.creatorId)

    peoplePreviewList = [
      %{
        id: user.id,
        displayName: user.displayName,
        numFollowers: user.numFollowers,
        avatarUrl: user.avatarUrl
      }
    ]

    # resp = raw_insert(data, peoplePreviewList)

    # resp =
    #  case resp do
    #    {:error, %{errors: [{:creatorId, {"has already been taken", _}}]}} ->
    #      raise "foo"
    #
    #    _ ->
    #      resp
    #  end

    # case resp do
    #  {:ok, room} ->
    #    Beef.Users.set_current_room(data.creatorId, room.id)
    #
    #  _ ->
    #    nil
    # end
    #
    # resp
  end

  def edit(room_id, data) do
    %Room{id: room_id}
    |> Room.edit_changeset(data)
    |> Repo.update()
  end
end
