defmodule Onion.RoomSession.Role do
  alias Broth.Message.Room.RoleUpdate
  alias Beef.Repo
  alias Beef.Users
  alias Onion.PubSub

  @authorized [:owner, :mod]

  def set_role_impl(user_id, opts, _reply, state) do
    case opts[:to] do
      :listener ->
        set_listener(user_id, opts[:by], state)

      :speaker ->
        set_speaker(user_id, opts[:by], state)

      :raised_hand ->
        set_raised_hand(user_id, opts[:by], state)
    end
  end

  ####################################################################
  ## listener

  # anyone can make themselves listeners
  defp set_listener(user_id, %{id: user_id}, state) do
    do_set_listener(user_id, state)
  end

  # no one can make the owner a listener
  defp set_listener(user_id, _, state = %{creatorId: user_id}) do
    {:reply, {:error, "permission denied"}, state}
  end

  defp set_listener(user_id, agent, state) do
    case Users.room_auth(agent) do
      auth when auth in @authorized ->
        do_set_listener(user_id, state)

      _ ->
        {:reply, {:error, "permission denied"}, state}
    end
  end

  defp do_set_listener(user_id, state = %{room: room}) do
    case Users.set_role(user_id, :listener) do
      {:ok, new_user!} ->
        new_user! = Repo.preload(new_user!, :currentRoom)

        PubSub.broadcast(
          "room:" <> room.id,
          %RoleUpdate{userId: user_id, role: :listener, roomId: room.id}
        )

        PubSub.broadcast("user:" <> user_id, new_user!)

        {:reply, :ok, %{state | room: new_user!.currentRoom}}

      error ->
        {:reply, error, state}
    end
  end

  ####################################################################
  ## speaker

  # only owners and mods are allowed to set speaker
  defp set_speaker(user_id, agent, state = %{room: room}) do
    with auth when auth in @authorized <- Users.room_auth(agent),
         {:ok, new_user!} <- Users.set_role(user_id, :speaker) do
      new_user! = Repo.preload(new_user!, :currentRoom)

      PubSub.broadcast(
        "room:" <> room.id,
        %RoleUpdate{userId: user_id, role: :speaker, roomId: room.id}
      )

      PubSub.broadcast("user:" <> user_id, new_user!)

      {:reply, :ok, %{state | room: new_user!.currentRoom}}
    else
      :listener ->
        {:reply, {:error, "permission denied"}, state}

      error ->
        {:reply, error, state}
    end
  end

  # only you can raise your own hand
  defp set_raised_hand(user_id, %{id: user_id}, state = %{room: room = %{autoSpeaker: a}}) do
    new_role = if a, do: :speaker, else: :raised_hand

    case Users.set_role(user_id, new_role) do
      {:ok, new_user!} ->
        new_user! = Repo.preload(new_user!, :currentRoom)

        PubSub.broadcast(
          "room:" <> room.id,
          %RoleUpdate{userId: user_id, role: new_role, roomId: room.id}
        )

        PubSub.broadcast("user:" <> user_id, new_user!)

        {:reply, :ok, %{state | room: new_user!.currentRoom}}

      error ->
        {:reply, error, state}
    end
  end

  defp set_raised_hand(_, _, state) do
    {:reply, {:error, "permission denied"}, state}
  end
end
