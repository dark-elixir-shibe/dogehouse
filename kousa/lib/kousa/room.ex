defmodule Kousa.Room do
  alias Kousa.Utils.VoiceServerUtils
  alias Beef.Users
  alias Beef.Follows
  alias Beef.Rooms

  alias Onion.PubSub
  alias Onion.RoomSession

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
      room = Rooms.get(user.currentRoomId)

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

  @authorized [:owner, :mod]

  def ban(user_id, opts) do
    agent = %{currentRoomId: room_id} = opts[:by]
    case Users.room_auth(agent) do
      auth when auth in @authorized ->
        Rooms.ban(room_id, user_id, Keyword.put(opts, :modId, agent.id))
        RoomSession.leave(room_id, user_id)
        :ok
      _ ->
        {:error, "permission denied"}
    end
  end

  def unban(user_id, opts) do
    agent = %{currentRoomId: room_id} = opts[:by]
    case Users.room_auth(agent) do
      auth when auth in @authorized ->
        Rooms.unban(room_id, user_id)
        RoomSession.unban(room_id, user_id)
      _ ->
        {:error, "permission denied"}
    end
  end

  def get_banned_users(room_id, opts) do
    agent = Keyword.get(opts, :by)
    with %{currentRoomId: ^room_id} <- agent,
         :owner <- Beef.Users.room_role(agent) do
      Rooms.get_banned_users(room_id, opts)
    else
      _ -> {:error, "permission denied"}
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

  defdelegate update(user_id, data), to: Onion.RoomSession

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
        Onion.Chat.start_supervised(room.id)

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
    # TODO here:
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

  # TODO: make USER_ID trampoline to USER struct.
  def leave(user_id, room_id \\ nil) do
    # TODO: CRASH IF NOT IN CURRENT ROOM.
    room_id =
      if is_nil(room_id),
        do: Beef.Users.get_current_room_id(user_id),
        else: room_id

    if room_id do
      case Rooms.leave(user_id, room_id) do
        # the room should be destroyed
        {:deleted, room} ->
          Onion.RoomSession.destroy(room_id, user_id)

          Onion.VoiceRabbit.send(room.voiceServerId, %{
            op: "destroy-room",
            uid: user_id,
            d: %{peerId: user_id, roomId: room_id}
          })

        # the room stays alive with new room creator
        x ->
          case x do
            {:new_creator_id, creator_id} ->
              Onion.RoomSession.broadcast_ws(
                room_id,
                %{op: "new_room_creator", d: %{roomId: room_id, userId: creator_id}}
              )

            _ ->
              nil
          end

          Onion.RoomSession.leave(room_id, user_id)
      end

      # unsubscribe to the room chat
      PubSub.unsubscribe("chat:" <> room_id)

      {:ok, %{roomId: room_id}}
    else
      {:error, "you are not in a room"}
    end
  end

  def mute(user = %{currentRoomId: nil}, _), do: nil
  def mute(user, muted?) do
    Onion.RoomSession.mute(user.currentRoomId, user.id, muted?)
  end
end
