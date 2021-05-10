defmodule BrothTest.Room.MuteTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Users
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    user_ws = WsClientFactory.create_client_for(user)

    %{"id" => room_id} =
      WsClient.do_call(
        user_ws,
        "room:create",
        %{"name" => "foo room", "description" => "foo"}
      )

    {:ok, user: user, user_ws: user_ws, room_id: room_id}
  end

  describe "the websocket room:mute operation" do
    test "can be used to mute", t do
      # first, create a room owned by the primary user.
      room_id = t.room_id
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # mute ON
      ref = WsClient.send_call(t.user_ws, "room:mute", %{"muted" => true})
      WsClient.assert_empty_reply(ref)
      Process.sleep(100)
      muted = Onion.RoomSession.get(room_id, :muteMap)
      assert t.user.id in muted

      # mute OFF
      ref = WsClient.send_call(t.user_ws, "room:mute", %{"muted" => false})
      WsClient.assert_empty_reply(ref)
      Process.sleep(100)
      muted = Onion.RoomSession.get(room_id, :muteMap)
      refute t.user.id in muted
    end

    test "can be used to unmute", t do
      # first, create a room owned by the primary user.
      room_id = t.room_id
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      ref = WsClient.send_call(t.user_ws, "room:mute", %{"muted" => false})

      WsClient.assert_empty_reply(ref)

      assert MapSet.new() == Onion.RoomSession.get(room_id, :muteMap)
    end
  end
end
