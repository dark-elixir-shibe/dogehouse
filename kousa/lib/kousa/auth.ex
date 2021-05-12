defmodule Kousa.Auth do
  alias Onion.PubSub

  alias Kousa.Utils.TokenUtils

  @spec authenticate(Broth.Message.Auth.Request.t(), IP.addr()) ::
          {:ok, Beef.Schemas.User.t()} | {:error, term}
  def authenticate(request, ip) do
    case TokenUtils.tokens_to_user_id(request.accessToken, request.refreshToken) do
      nil ->
        {:error, "invalid_authentication"}

      {:existing_claim, user_id} ->
        do_auth(Beef.Users.get(user_id), nil, request, ip)

      # TODO: streamline this since we're duplicating user_id and user.
      {:new_tokens, _user_id, tokens, user} ->
        do_auth(user, tokens, request, ip)
    end
  end

  defp do_auth(user, _tokens, request, ip) do
    alias Onion.RoomSession
    alias Beef.Rooms

    if user do

      if user.ip != ip do
        Beef.Users.set_ip(user.id, ip)
      end

      # can we trust this?
      roomIdFromFrontend = request.currentRoomId

      cond do
        user.currentRoomId ->
          # TODO: move to room business logic
          room = Rooms.get(user.currentRoomId)

          RoomSession.start_supervised(
            room_id: user.currentRoomId,
            voice_server_id: room.voiceServerId
          )

          raise "error"
          #RoomSession.join_room(room.id, user.id, request.muted, request.deafened)
#
          #if request.reconnectToVoice == true do
          #  Kousa.Room.join_vc_room(user.id, room)
          #end

        roomIdFromFrontend ->
          raise "error"
          #Kousa.Room.join_room(user.id, roomIdFromFrontend)

        true ->
          :ok
      end

      # subscribe to chats directed to oneself.
      PubSub.subscribe("chat:" <> user.id)
      # subscribe to user updates
      PubSub.subscribe("user:" <> user.id)

      {:ok, user}
    else
      {:close, 4001, "invalid_authentication"}
    end
  end
end
