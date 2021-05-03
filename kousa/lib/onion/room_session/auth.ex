defmodule Onion.RoomSession.Auth do
  @moduledoc false

  alias Beef.Rooms
  alias Beef.Users
  alias Broth.Message.Room.AuthUpdate
  alias Onion.PubSub

  ## organizational module for handling Auth concerns for the
  ## RoomSession GenServer.

  def set_auth_impl(user_id, opts, _reply, state) do
    case opts[:to] do
      :owner ->
        set_owner(user_id, opts[:by], state)

      :mod ->
        set_mod(user_id, opts[:by], state)

      :user ->
        set_user(user_id, opts[:by], state)
    end
  end

  ####################################################################
  # owner

  def set_owner(user_id, owner, state = %{room: room}) do
    with :owner <- Users.room_auth(owner),
         {:ok, new_room} <- Rooms.replace_owner(room, user_id) do
      PubSub.broadcast(
        "room:" <> room.id,
        %AuthUpdate{userId: user_id, auth: :owner, roomId: room.id}
      )

      {:reply, :ok, %{state | room: new_room}}
    else
      auth when auth in [:mod, :user] ->
        {:reply, {:error, "permission denied"}, state}

      error ->
        {:reply, error, state}
    end
  end

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
