defmodule Beef.Rooms do
  @moduledoc """
  Empty context module for Rooms
  """

  # ACCESS functions
  defdelegate get(room_id), to: Beef.Access.Rooms

  defdelegate banned?(room_id, user_id), to: Beef.Access.Rooms

  defdelegate get_top_public_rooms(user_id, offset \\ 0), to: Beef.Access.Rooms
  defdelegate get_next_creator_for_room(room_id), to: Beef.Access.Rooms
  defdelegate get_room_by_creator_id(creator_id), to: Beef.Access.Rooms
  defdelegate search_name(start_of_name), to: Beef.Access.Rooms

  @spec all_rooms :: any
  defdelegate all_rooms(), to: Beef.Access.Rooms

  # LENSES
  defdelegate can_join(room, user_id), to: Beef.Lenses.Rooms
  defdelegate count_attendees(room), to: Beef.Lenses.Rooms

  # MUTATION functions
  defdelegate update(changeset), to: Beef.Repo
  defdelegate replace_owner(room, user_id), to: Beef.Mutations.Rooms

  # ban mutations (note these go to RoomBlocks)
  defdelegate ban(room_id, user_id, opts), to: Beef.Mutations.RoomBlocks
  defdelegate unban(room_id, user_id), to: Beef.Mutations.RoomBlocks

  defdelegate set_room_privacy_by_creator_id(user_id, isPrivate, new_name),
    to: Beef.Mutations.Rooms

  defdelegate delete_room_by_id(room_id), to: Beef.Mutations.Rooms
  defdelegate leave(user_id, room_id), to: Beef.Mutations.Rooms
  defdelegate update_name(user_id, name), to: Beef.Mutations.Rooms
  defdelegate create(data), to: Beef.Mutations.Rooms
  defdelegate edit(room_id, data), to: Beef.Mutations.Rooms
end
