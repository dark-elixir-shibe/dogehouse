defmodule Onion.RoomSession.Auth do
  @moduledoc false

  ## organizational module for handling Auth concerns for the
  ## RoomSession GenServer.

####################################################################
# owner

#def set_owner(room_id, user_id, setter_id) do
#  with {:creator, _} <- Rooms.get_room_status(setter_id),
#       {1, _} <- Rooms.replace_room_owner(setter_id, user_id) do
#    internal_set_speaker(setter_id, room_id)

#    Onion.RoomSession.broadcast_ws(
#      room_id,
#      %{
#        op: "new_room_creator",
#        d: %{roomId: room_id, userId: user_id}
#      }
#    )
#  end
#end

####################################################################
# mod

# only creators can set someone to be mod.
defp set_mod(room_id, user_id, setter_id) do
  # TODO: refactor this to pull from preloads.
  case Rooms.get_room_status(setter_id) do
    {:creator, _} ->
      RoomPermissions.set_is_mod(user_id, room_id, true)

      Onion.RoomSession.broadcast_ws(
        room_id,
        %{
          op: "mod_changed",
          d: %{roomId: room_id, userId: user_id}
        }
      )

    _ ->
      :noop
  end
end

####################################################################
# plain user

# mods can demote their own mod status.
defp set_user(room_id, user_id, user_id) do
  case Rooms.get_room_status(user_id) do
    {:mod, _} ->
      RoomPermissions.set_is_mod(user_id, room_id, true)

      Onion.RoomSession.broadcast_ws(
        room_id,
        %{
          op: "mod_changed",
          d: %{roomId: room_id, userId: user_id}
        }
      )

    _ ->
      :noop
  end
end

# only creators can demote mods
defp set_user(room_id, user_id, setter_id) do
  case Rooms.get_room_status(setter_id) do
    {:creator, _} ->
      RoomPermissions.set_is_mod(user_id, room_id, false)

      Onion.RoomSession.broadcast_ws(
        room_id,
        %{
          op: "mod_changed",
          d: %{roomId: room_id, userId: user_id}
        }
      )

    _ ->
      :noop
  end
end

end
