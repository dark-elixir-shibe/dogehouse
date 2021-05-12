defmodule Onion.RoomSession.Auth do
  @moduledoc false

  alias Beef.Repo
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
        %AuthUpdate{userId: user_id, level: :owner, roomId: room.id}
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
  defp set_mod(user_id, owner, state = %{room: room}) do
    with :owner <- Users.room_auth(owner),
         {:ok, new_user!} <- Users.set_auth(user_id, :mod) do
      new_user! = Repo.preload(new_user!, :currentRoom)

      PubSub.broadcast(
        "room:" <> room.id,
        %AuthUpdate{userId: user_id, level: :mod, roomId: room.id}
      )

      PubSub.broadcast("user:" <> new_user!.id, new_user!)

      {:reply, :ok, %{state | room: new_user!.currentRoom}}
    else
      auth when auth in [:mod, :user] ->
        {:reply, {:error, "permission denied"}, state}

      error ->
        {:reply, error, state}
    end
  end

  ####################################################################
  # plain user

  # mods can demote their own mod status.
  defp set_user(user_id, agent = %{id: user_id}, state = %{room: room}) do
    with :mod <- Users.room_auth(agent),
         {:ok, new_user!} <- Users.set_auth(user_id, :user) do
      new_user! = Repo.preload(new_user!, :currentRoom)

      PubSub.broadcast(
        "room:" <> room.id,
        %AuthUpdate{userId: user_id, level: :user, roomId: room.id}
      )

      PubSub.broadcast("user:" <> new_user!.id, new_user!)

      {:reply, :ok, %{state | room: new_user!.currentRoom}}
    else
      auth when auth in [:owner, :user] ->
        {:reply, {:error, "permission denied"}, state}

      error ->
        {:reply, error, state}
    end
  end

  # only creators can demote mods
  defp set_user(user_id, agent, state = %{room: room}) do
    with :owner <- Users.room_auth(agent),
         {:ok, new_user!} <- Users.set_auth(user_id, :user) do
      new_user! = Repo.preload(new_user!, :currentRoom)

      PubSub.broadcast(
        "room:" <> room.id,
        %AuthUpdate{userId: user_id, level: :user, roomId: room.id}
      )

      PubSub.broadcast("user:" <> new_user!.id, new_user!)

      {:reply, :ok, %{state | room: new_user!.currentRoom}}
    else
      auth when auth in [:mod, :user] ->
        {:reply, {:error, "permission denied"}, state}

      error ->
        {:reply, error, state}
    end
  end
end
