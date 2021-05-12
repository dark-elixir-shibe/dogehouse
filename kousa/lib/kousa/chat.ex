defmodule Kousa.Chat do
  alias Broth.Message.Chat.Delete
  alias Kousa.Utils.UUID
  alias Onion.Chat

  def send_msg(_payload, to: nil), do: nil

  def send_msg(payload, to: room) do
    Onion.Chat.send_msg(room.id, payload)
  end

  @ban_roles [:owner, :mod]

  def ban_user(user_id, opts) do
    agent = opts[:by]

    case Beef.Users.room_auth(agent) do
      role when role in @ban_roles ->
        Chat.ban_user(agent.currentRoomId, user_id)

      _ ->
        {:error, "#{agent.id} not authorized to ban #{user_id}"}
    end
  end

  def unban_user(user_id, opts) do
    agent = opts[:by]

    case Beef.Users.room_auth(agent) do
      role when role in @ban_roles ->
        Chat.unban_user(agent.currentRoomId, user_id)

      _ ->
        {:error, "#{agent.id} not authorized to unban #{user_id}"}
    end
  end

  @type delete_opts :: [by: UUID.t()]
  @spec delete_msg(Delete.t(), delete_opts) :: :ok
  # Delete room chat messages
  def delete_msg(_deletion, opts) do
    _user_id = opts[:by]

    raise "FOO"

    #room =
    #  case Rooms.get_room_status(user_id) do
    #    {:creator, room} ->
    #      room
#
    #    # Mods cannot delete creator's messages
    #    {:mod, room = %{creatorId: creator_id}}
    #    when user_id != creator_id ->
    #      room
#
    #    {:listener, room} when user_id == deletion.userId ->
    #      room
#
    #    _ ->
    #      nil
    #  end
#
    #if room do
    #  Onion.Chat.delete_message(room.id, deletion)
    #else
    #  {:error, "#{user_id} not authorized to delete the selected message"}
    #end
  end
end
