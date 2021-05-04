defmodule BrothTest.Room.DeafenTest do
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

  describe "the websocket room:deafen operation" do
    test "can be used to deafen", t do
      room_id = t.room_id
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # deaf ON
      ref = WsClient.send_call(t.user_ws, "room:deafen", %{"deafened" => true})
      WsClient.assert_empty_reply(ref)
      Process.sleep(100)
      map = Onion.RoomSession.get(room_id, :deafMap)
      assert is_map_key(map, t.user.id)

      # deaf OFF
      ref = WsClient.send_call(t.user_ws, "room:deafen", %{"deafened" => false})
      WsClient.assert_empty_reply(ref)
      Process.sleep(100)
      map = Onion.RoomSession.get(room_id, :deafMap)
      refute is_map_key(map, t.user.id)
    end

    test "can be used to undeafen", t do
      room_id = t.room_id
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      ref = WsClient.send_call(t.user_ws, "room:deafen", %{"deafened" => false})

      WsClient.assert_empty_reply(ref)

      map = Onion.RoomSession.get(room_id, :deafMap)

      assert map == %{}
    end
  end
end
