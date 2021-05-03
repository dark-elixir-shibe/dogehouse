defmodule Kousa.Room do
  alias Kousa.Utils.VoiceServerUtils
  alias Beef.Users
  alias Beef.Follows
  alias Beef.Rooms
  # note the following 2 module aliases are on the chopping block!
  alias Beef.RoomPermissions
  alias Beef.RoomBlocks
  alias Onion.PubSub

  alias Beef.Schemas.Room
  alias Beef.Schemas.User

  def set_auto_speaker(user_id, value) do
    if room = Rooms.get_room_by_creator_id(user_id) do
      Onion.RoomSession.set_auto_speaker(room.id, value)
    end
  end

  @spec make_room_public(any, any) :: nil | :ok
  def make_room_public(user_id, new_name) do
    # this needs to be refactored if a user can have multiple rooms
    case Beef.Rooms.set_room_privacy_by_creator_id(user_id, false, new_name) do
      {1, [room]} ->
        Onion.RoomSession.broadcast_ws(
          room.id,
          %{op: "room_privacy_change", d: %{roomId: room.id, name: room.name, isPrivate: false}}
        )

      _ ->
        nil
    end
  end

  @spec make_room_private(any, any) :: nil | :ok
  def make_room_private(user_id, new_name) do
    # this needs to be refactored if a user can have multiple rooms
    case Rooms.set_room_privacy_by_creator_id(user_id, true, new_name) do
      {1, [room]} ->
        Onion.RoomSession.broadcast_ws(
          room.id,
          %{op: "room_privacy_change", d: %{roomId: room.id, name: room.name, isPrivate: true}}
        )

      _ ->
        nil
    end
  end

  def invite_to_room(user_id, user_id_to_invite) do
    user = Beef.Users.get_by_id(user_id)

    if user.currentRoomId && Follows.following_me?(user_id, user_id_to_invite) do
      # @todo store room name in RoomSession to avoid db lookups
      room = Rooms.get_room_by_id(user.currentRoomId)

      if not is_nil(room) do
        Onion.RoomSession.create_invite(
          user.currentRoomId,
          user_id_to_invite,
          %{
            roomName: room.name,
            displayName: user.displayName,
            username: user.username,
            avatarUrl: user.avatarUrl,
            bannerUrl: user.bannerUrl,
            type: "invite"
          }
        )
      end
    end
  end

  defp internal_kick_from_room(user_id_to_kick, room_id) do
    current_room_id = Beef.Users.get_current_room_id(user_id_to_kick)

    if current_room_id == room_id do
      Rooms.kick_from_room(user_id_to_kick, current_room_id)
      Onion.RoomSession.kick_from_room(current_room_id, user_id_to_kick)
    end
  end

  @spec block_from_room(String.t(), String.t(), boolean()) ::
          nil
          | :ok
          | {:askedToSpeak | :creator | :listener | :mod | nil | :speaker,
             atom | %{:creatorId => any, optional(any) => any}}
  def block_from_room(user_id, user_id_to_block_from_room, should_ban_ip \\ false) do
    with {status, room} when status in [:creator, :mod] <-
           Rooms.get_room_status(user_id) do
      if room.creatorId != user_id_to_block_from_room do
        RoomBlocks.upsert(%{
          modId: user_id,
          userId: user_id_to_block_from_room,
          roomId: room.id,
          ip: if(should_ban_ip, do: Users.get_ip(user_id_to_block_from_room), else: nil)
        })

        internal_kick_from_room(user_id_to_block_from_room, room.id)
      end
    end
  end

  ###################################################################
  ## AUTH

  @type auth_opts :: [by: UUID.t(), to: Broth.Message.Types.RoomRole.t()]

  @doc """
  sets the role of the user in the room that they're in.

  Role level is specified by the `:to` keyword parameter.

  Authorization to do so is pulled from the options `:by` keyword.
  """
  @spec set_auth(User.t(), UUID.t(), auth_opts) :: :ok | {:error, term}
  def set_auth(room_id, target_id, opts) do
    Onion.RoomSession.set_auth(room_id, target_id, opts)
  end

  ####################################################################
  ## ROLE

  @type role_opts :: [by: UUID.t(), to: Broth.Message.Types.RoomRole.t()]

  @doc """
  sets the role of the user in the room that they're in.

  Role level is specified by the `:to` keyword parameter.

  Authorization to do so is pulled from the options `:by` keyword.
  """
  @spec set_role(UUID.t(), UUID.t(), role_opts) :: :ok | {:error, term}
  def set_role(room_id, target_id, opts) do
    Onion.RoomSession.set_role(room_id, target_id, opts)
  end

  ######################################################################
  ## UPDATE

  def update(user_id, data) do
    if room = Rooms.get_room_by_creator_id(user_id) do
      case Rooms.edit(room.id, data) do
        ok = {:ok, room} ->
          Onion.RoomSession.broadcast_ws(room.id, %{
            op: "new_room_details",
            d: %{
              name: room.name,
              description: room.description,
              isPrivate: room.isPrivate,
              roomId: room.id
            }
          })

          ok

        error = {:error, _} ->
          error
      end
    end
  end

  def join_vc_room(room, user_id, speaker?) do
    op =
      if speaker?,
        do: "join-as-speaker",
        else: "join-as-new-peer"

    Onion.VoiceRabbit.send(room.voiceServerId, %{
      op: op,
      d: %{roomId: room.id, peerId: user_id},
      uid: user_id
    })
  end

  @spec create_with(Ecto.Changeset.t(), User.t()) :: {:ok, Room.t(), User.t()} | {:error, term}
  def create_with(changeset, user) do
    changeset
    |> Ecto.Changeset.change(voiceServerId: VoiceServerUtils.get_next_voice_server_id())
    |> Beef.Repo.insert()
    |> case do
      {:ok, room} ->
        Onion.RoomSession.start_supervised(room)

        # send commands to the Voice AMQP channel
        # TODO: move this into Onion.RoomSession
        Onion.VoiceRabbit.send(room.voiceServerId, %{
          op: "create-room",
          d: %{roomId: room.id},
          uid: user.id
        })

        Enum.each(room.userIdsToInvite, &invite_to_room(room, &1, from: user.id))

        join(room.id, user, speaker: true)

      error ->
        error
    end
  end

  @typep join_result :: {:ok, Room.t(), User.t()} | {:ok, :noop} | {:error, term}
  @typep join_opts :: [speaker: boolean]

  @spec join(UUID.t(), User.t()) :: join_result
  @spec join(UUID.t(), User.t(), join_opts) :: join_result

  def join(room_id, user, opts \\ [])

  # no-op when the user is already in the room.
  def join(room_id, %{currentRoomId: room_id}, _) do
    {:ok, :noop}
  end

  # normal path: when the user is not in a room.
  def join(room_id, user = %{currentRoomId: nil}, opts) do
    case Onion.RoomSession.join(room_id, user, opts) do
      {:ok, room, user} ->
        # subscribe to the room info and room chat channels
        Onion.PubSub.subscribe("room:" <> room_id)
        Onion.PubSub.subscribe("chat:" <> room_id)

        # connect the user to the voicechat server
        # TODO: make sure roomPermissions is a correctly assigned preload.
        join_vc_room(room, user.id, user.roomPermissions.isSpeaker || room.isPrivate)

        {:ok, room, user}

      error ->
        error
    end
  end

  # if the user is in a room, leave it, then clear the room.
  def join(room_id, user, opts) do
    leave(room_id, user)
    join(room_id, %{user | currentRoomId: nil}, opts)
  end

  defp invite_to_room(room, invite_id, from: user_id) do
    alias Broth.Message.User.Invitation

    PubSub.broadcast("user:" <> invite_id, %Invitation{
      roomId: room.id,
      name: room.name,
      fromUserId: user_id
    })
  end

  def leave(room, user), do: {:ok, room, user}

  def leave_room(user_id, current_room_id \\ nil) do
    current_room_id =
      if is_nil(current_room_id),
        do: Beef.Users.get_current_room_id(user_id),
        else: current_room_id

    if current_room_id do
      case Rooms.leave_room(user_id, current_room_id) do
        # the room should be destroyed
        {:bye, room} ->
          Onion.RoomSession.destroy(current_room_id, user_id)

          Onion.VoiceRabbit.send(room.voiceServerId, %{
            op: "destroy-room",
            uid: user_id,
            d: %{peerId: user_id, roomId: current_room_id}
          })

        # the room stays alive with new room creator
        x ->
          case x do
            {:new_creator_id, creator_id} ->
              Onion.RoomSession.broadcast_ws(
                current_room_id,
                %{op: "new_room_creator", d: %{roomId: current_room_id, userId: creator_id}}
              )

            _ ->
              nil
          end

          Onion.RoomSession.leave_room(current_room_id, user_id)
      end

      # unsubscribe to the room chat
      PubSub.unsubscribe("chat:" <> current_room_id)

      {:ok, %{roomId: current_room_id}}
    else
      {:error, "you are not in a room"}
    end
  end
end
