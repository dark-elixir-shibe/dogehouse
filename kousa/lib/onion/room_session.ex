defmodule Onion.RoomSession do
  use GenServer, restart: :temporary

  alias Kousa.Utils.UUID
  alias Onion.PubSub
  alias Beef.Schemas.Room
  alias Beef.Schemas.User
  alias Beef.Rooms
  alias Beef.Users

  @type uuid_set :: MapSet.t(UUID.t())

  @type state :: %__MODULE__{
          room: Room.t(),
          voice_server_id: String.t(),
          attendees: uuid_set(),
          muteMap: uuid_set(),
          deafMap: uuid_set(),
          inviteMap: uuid_set(),
          activeSpeakerMap: uuid_set(),
          auto_speaker: boolean(),
          callers: list(pid)
        }

  @empty_set MapSet.new()

  defstruct [
    :room,
    :voice_server_id,
    attendees: @empty_set,
    muteMap: @empty_set,
    deafMap: @empty_set,
    inviteMap: @empty_set,
    activeSpeakerMap: @empty_set,
    auto_speaker: false,
    callers: []
  ]

  @registry Onion.RoomSessionRegistry

  #################################################################################
  # REGISTRY AND SUPERVISION BOILERPLATE

  defp via(user_id), do: {:via, Registry, {@registry, user_id}}

  defp cast(user_id, params), do: GenServer.cast(via(user_id), params)
  defp call(user_id, params), do: GenServer.call(via(user_id), params)

  def start_supervised(room) do
    callers = [self() | Process.get(:"$callers", [])]

    case DynamicSupervisor.start_child(
           Onion.RoomSessionDynamicSupervisor,
           {__MODULE__, %__MODULE__{room: room, callers: callers}}
         ) do
      {:error, {:already_started, pid}} -> {:ignored, pid}
      error -> error
    end
  end

  def child_spec(init), do: %{super(init) | id: init.room.id}

  def count, do: Registry.count(@registry)
  def lookup(room_id), do: Registry.lookup(@registry, room_id)

  ###############################################################################
  ## INITIALIZATION BOILERPLATE

  def start_link(init) do
    GenServer.start_link(__MODULE__, init, name: via(init.room.id))
  end

  def init(init) do
    # adopt callers from the call point.
    Process.put(:"$callers", init.callers)

    # also launch a linked, supervised room.
    Onion.Chat.start_link_supervised(init.room.id)

    # broadcast a notification that room has been created.
    PubSub.broadcast("room:all", init.room)

    {:ok, init}
  end

  ########################################################################
  ## API

  @spec alive?(UUID.t()) :: boolean

  ########################################################################
  ## API IMPLEMENTATION

  def alive?(room_id) do
    match?([_], Registry.lookup(@registry, room_id))
  end

  def ws_fan(_, _), do: raise "use PubSub!"

  def update(room_id, changeset), do: call(room_id, {:update, changeset})

  defp update_impl(changeset, _reply, state) do
    changes = changeset.changes
    {reply, new_state} = case Rooms.update(changeset) do
      {:ok, room} ->
        if Map.has_key?(changes, :isPrivate) do
          # send the room_privacy_change message.
          PubSub.broadcast("room:" <> room.id, %Broth.Message.Room.PrivacyUpdate{
            isPrivate: changes.isPrivate,
            name: room.name,
            roomId: room.id
          })
        end

        # generic room update
        PubSub.broadcast("room:" <> room.id, room)
        {{:ok, room}, %{state | room: room}}
      error -> error
    end
    {:reply, reply, new_state}
  end

  def get(room_id, key), do: call(room_id, {:get, key})

  defp get_impl(key, _reply, state) do
    {:reply, Map.get(state, key), state}
  end

  def get_maps(room_id), do: call(room_id, :get_maps)

  defp get_maps_impl(_reply, state) do
    {:reply, {state.muteMap, state.deafMap, state.auto_speaker, state.activeSpeakerMap}, state}
  end

  def redeem_invite(room_id, user_id), do: call(room_id, {:redeem_invite, user_id})

  defp redeem_invite_impl(user_id, _reply, state) do
    reply = if Map.has_key?(state.inviteMap, user_id), do: :ok, else: :error

    {:reply, reply, %{state | inviteMap: Map.delete(state.inviteMap, user_id)}}
  end

  def speaking_change(room_id, user_id, value) do
    cast(room_id, {:speaking_change, user_id, value})
  end

  defp speaking_change_impl(user_id, value, state) when is_boolean(value) do
    alias Broth.Message.Room.SpeakingUpdate

    muteMap = if value, do: MapSet.delete(state.muteMap, user_id), else: state.muteMap
    deafMap = if value, do: MapSet.delete(state.deafMap, user_id), else: state.deafMap

    activeSpeakerMap =
      if value,
        do: MapSet.put(state.activeSpeakerMap, user_id),
        else: MapSet.delete(state.activeSpeakerMap, user_id)

    Onion.PubSub.broadcast(
      "room:" <> state.room.id,
      %SpeakingUpdate{
        activeSpeakerMap: activeSpeakerMap,
        roomId: state.room.id,
        muteMap: muteMap,
        deafMap: deafMap
      }
    )

    {:noreply, %{state | activeSpeakerMap: activeSpeakerMap, muteMap: muteMap, deafMap: deafMap}}
  end

  def set_auto_speaker(room_id, value) when is_boolean(value) do
    cast(room_id, {:set_auto_speaker, value})
  end

  defp set_auto_speaker_impl(value, state) do
    {:noreply, %{state | auto_speaker: value}}
  end

  def broadcast_ws(room_id, msg), do: cast(room_id, {:broadcast_ws, msg})

  defp broadcast_ws_impl(msg, state) do
    ws_fan(state.attendees, msg)
    {:noreply, state}
  end

  def create_invite(room_id, user_id, user_info) do
    cast(room_id, {:create_invite, user_id, user_info})
  end

  defp create_invite_impl(user_id, user_info, state) do
    Onion.UserSession.send_ws(
      user_id,
      nil,
      %{
        op: "invitation_to_room",
        d:
          Map.merge(
            %{roomId: state.room_id},
            user_info
          )
      }
    )

    {:noreply,
     %{
       state
       | inviteMap: Map.put(state.inviteMap, user_id, true)
     }}
  end

  def remove_speaker(room_id, user_id), do: cast(room_id, {:remove_speaker, user_id})

  defp remove_speaker_impl(user_id, state) do
    new_mm = Map.delete(state.muteMap, user_id)
    new_dm = Map.delete(state.deafMap, user_id)

    Onion.VoiceRabbit.send(state.voice_server_id, %{
      op: "remove-speaker",
      d: %{roomId: state.room_id, peerId: user_id},
      uid: user_id
    })

    ws_fan(state.attendees, %{
      op: "speaker_removed",
      d: %{
        userId: user_id,
        roomId: state.room_id,
        muteMap: new_mm,
        deafMap: new_dm,
        raiseHandMap: %{}
      }
    })

    {:noreply, %{state | muteMap: new_mm, deafMap: new_dm}}
  end

  def add_speaker(room_id, user_id, muted?, deafened?)
      when is_boolean(muted?) and is_boolean(deafened?) do
    cast(room_id, {:add_speaker, user_id, muted?, deafened?})
  end

  def add_speaker_impl(user_id, muted?, deafened?, state) do
    new_mm =
      if muted?,
        do: Map.put(state.muteMap, user_id, true),
        else: Map.delete(state.muteMap, user_id)

    new_dm =
      if(deafened?,
        do: Map.put(state.deafMap, user_id, true),
        else: Map.delete(state.deafMap, user_id)
      )

    Onion.VoiceRabbit.send(state.voice_server_id, %{
      op: "add-speaker",
      d: %{roomId: state.room_id, peerId: user_id},
      uid: user_id
    })

    ws_fan(state.attendees, %{
      op: "speaker_added",
      d: %{
        userId: user_id,
        roomId: state.room_id,
        muteMap: new_mm,
        deafMap: new_dm
      }
    })

    {:noreply, %{state | muteMap: new_mm, deafMap: new_dm}}
  end

  @spec join(UUID.t(), User.t(), keyword) :: {:ok, Room.t(), User.t()} | {:error, term}
  def join(room_id, user, opts) do
    call(room_id, {:join, user, opts})
  end

  defp join_impl(user, opts, _reply, state = %{room: room}) do
    user_id = user.id
    room_id = room.id

    with :ok <- Rooms.can_join(room, user_id),
         {:ok, updated_user} <- Users.join_room(user, room_id, opts) do
      updated_room = updated_user.currentRoom

      Onion.Chat.add_user(room_id, user_id)

      muteMap = mapset_add_if(state.muteMap, user_id, user.muted)
      deafMap = mapset_add_if(state.deafMap, user_id, user.deafened)

      new_state = %{state | room: updated_room, muteMap: muteMap, deafMap: deafMap}

      # Broadcast.
      PubSub.broadcast(
        "room:" <> room_id,
        %Broth.Message.Room.Joined{
          user: updated_user,
          muteMap: muteMap,
          deafMap: deafMap
        }
      )

      {:reply, {:ok, updated_room, updated_user}, new_state}
    else
      error ->
        {:reply, error, state}
    end
  end

  defp mapset_add_if(mapset, value, condition) do
    if condition, do: MapSet.put(mapset, value), else: MapSet.delete(mapset, value)
  end

  ###################################################################
  ## SET AUTH
  # get the implementation from the other module.
  import Onion.RoomSession.Auth, only: [set_auth_impl: 4]

  def set_auth(room_id, user_id, opts) do
    call(room_id, {:set_auth, user_id, opts})
  end

  ###################################################################
  ## SET ROLE
  import Onion.RoomSession.Role, only: [set_role_impl: 4]

  def set_role(room_id, user_id, opts) do
    call(room_id, {:set_role, user_id, opts})
  end

  #############################################################################

  def mute(room_id, user_id, value), do: cast(room_id, {:mute, user_id, value})

  defp mute_impl(user_id, value, state) do
    changed = value != Map.has_key?(state.muteMap, user_id)

    if changed do
      ws_fan(Enum.filter(state.attendees, &(&1 != user_id)), %{
        op: "mute_changed",
        d: %{userId: user_id, value: value, roomId: state.room_id}
      })
    end

    {:noreply,
     %{
       state
       | muteMap:
           if(not value,
             do: Map.delete(state.muteMap, user_id),
             else: Map.put(state.muteMap, user_id, true)
           ),
         activeSpeakerMap:
           if(value, do: Map.delete(state.activeSpeakerMap, user_id), else: state.activeSpeakerMap),
         deafMap: if(value, do: Map.delete(state.deafMap, user_id), else: state.deafMap)
     }}
  end

  def deafen(room_id, user_id, value), do: cast(room_id, {:deafen, user_id, value})

  defp deafen_impl(user_id, value, state) do
    changed = value != Map.has_key?(state.deafMap, user_id)

    if changed do
      ws_fan(Enum.filter(state.attendees, &(&1 != user_id)), %{
        op: "deafen_changed",
        d: %{userId: user_id, value: value, roomId: state.room_id}
      })
    end

    {:noreply,
     %{
       state
       | deafMap:
           if(not value,
             do: Map.delete(state.deafMap, user_id),
             else: Map.put(state.deafMap, user_id, true)
           ),
         activeSpeakerMap:
           if(value, do: Map.delete(state.activeSpeakerMap, user_id), else: state.activeSpeakerMap),
         muteMap: if(value, do: Map.delete(state.muteMap, user_id), else: state.muteMap)
     }}
  end

  def destroy(room_id, user_id), do: cast(room_id, {:destroy, user_id})

  defp destroy_impl(user_id, state) do
    attendees = Enum.filter(state.attendees, fn uid -> uid != user_id end)

    ws_fan(attendees, %{
      op: "room_destroyed",
      d: %{roomId: state.room.id}
    })

    {:stop, :normal, state}
  end

  def leave_room(room_id, user_id), do: cast(room_id, {:leave_room, user_id})

  defp leave_room_impl(user_id, state) do
    attendees = Enum.reject(state.attendees, &(&1 == user_id))

    Onion.Chat.remove_user(state.room.id, user_id)

    Onion.VoiceRabbit.send(state.voice_server_id, %{
      op: "close-peer",
      uid: user_id,
      d: %{peerId: user_id, roomId: state.room.id}
    })

    ws_fan(attendees, %{
      op: "user_left_room",
      d: %{userId: user_id, roomId: state.room.id}
    })

    new_state = %{
      state
      | attendees: attendees,
        muteMap: Map.delete(state.muteMap, user_id),
        deafMap: Map.delete(state.deafMap, user_id)
    }

    # terminate room if it's empty
    case new_state.attendees do
      [] ->
        {:stop, :normal, new_state}

      _ ->
        {:noreply, new_state}
    end
  end

  # for testing purposes only.
  if Mix.env() == :test do
    def dump(room_id), do: call(room_id, :dump)
    def dump_impl(_reply, state), do: {:reply, state, state}
  end

  ########################################################################
  ## ROUTER

  def handle_call({:get, key}, reply, state), do: get_impl(key, reply, state)

  def handle_call(:get_maps, reply, state), do: get_maps_impl(reply, state)

  def handle_call({:update, changeset}, reply, state), do: update_impl(changeset, reply, state)

  def handle_call({:redeem_invite, user_id}, reply, state) do
    redeem_invite_impl(user_id, reply, state)
  end

  def handle_call({:join, user, opts}, reply, state) do
    join_impl(user, opts, reply, state)
  end

  def handle_call({:set_auth, user, opts}, reply, state) do
    set_auth_impl(user, opts, reply, state)
  end

  def handle_call({:set_role, user, opts}, reply, state) do
    set_role_impl(user, opts, reply, state)
  end

  if Mix.env() == :test do
    def handle_call(:dump, reply, state) do
      dump_impl(reply, state)
    end
  end

  def handle_cast({:speaking_change, user_id, value}, state) do
    speaking_change_impl(user_id, value, state)
  end

  def handle_cast({:set_auto_speaker, value}, state) do
    set_auto_speaker_impl(value, state)
  end

  def handle_cast({:broadcast_ws, msg}, state) do
    broadcast_ws_impl(msg, state)
  end

  def handle_cast({:create_invite, user_id, user_info}, state) do
    create_invite_impl(user_id, user_info, state)
  end

  def handle_cast({:remove_speaker, user_id}, state) do
    remove_speaker_impl(user_id, state)
  end

  def handle_cast({:add_speaker, user_id, muted?, deafened?}, state) do
    add_speaker_impl(user_id, muted?, deafened?, state)
  end

  def handle_cast({:mute, user_id, value}, state) do
    mute_impl(user_id, value, state)
  end

  def handle_cast({:deafen, user_id, value}, state) do
    deafen_impl(user_id, value, state)
  end

  def handle_cast({:destroy, user_id}, state) do
    destroy_impl(user_id, state)
  end

  def handle_cast({:leave_room, user_id}, state) do
    leave_room_impl(user_id, state)
  end
end
