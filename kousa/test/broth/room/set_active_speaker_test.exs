defmodule BrothTest.Room.SetActiveSpeakerTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
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

  describe "the websocket room:set_active_speaker operation" do
    test "toggles the active speaking state", t do
      room_id = t.room_id

      # add a second user to the test
      other = Factory.create(User)
      other_ws = WsClientFactory.create_client_for(other)
      WsClient.do_call(other_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame("room:joined", _)

      ref = WsClient.send_call(
        t.user_ws,
        "room:set_active_speaker",
        %{"active" => true}
      )

      WsClient.assert_empty_reply(ref)

      # both websockets will be informed
      WsClient.assert_frame(
        "room:speaking_update",
        %{"activeSpeakerMap" => map},
        t.user_ws
      )

      assert is_map_key(map, t.user.id)

      WsClient.assert_frame(
        "room:speaking_update",
        %{"activeSpeakerMap" => map},
        other_ws
      )

      assert is_map_key(map, t.user.id)
      assert t.user.id in Onion.RoomSession.get(room_id, :activeSpeakerMap)

      Process.sleep(100)

      ref = WsClient.send_call(
        t.user_ws,
        "room:set_active_speaker",
        %{"active" => false}
      )

      WsClient.assert_empty_reply(ref)

      WsClient.assert_frame(
        "room:speaking_update",
        %{"activeSpeakerMap" => map},
        t.user_ws
      )

      refute is_map_key(map, t.user.id)

      WsClient.assert_frame(
        "room:speaking_update",
        %{"activeSpeakerMap" => map},
        other_ws
      )

      refute is_map_key(map, t.user.id)

      map = Onion.RoomSession.get(room_id, :activeSpeakerMap)

      refute is_map_key(map, t.user.id)
    end

    test "does nothing if it's unset", t do
      room_id = t.room_id

      # add a second user to the test
      other = Factory.create(User)
      other_ws = WsClientFactory.create_client_for(other)
      WsClient.do_call(other_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame("room:joined", _)

      Onion.RoomSession.get(room_id, :activeSpeakerMap)

      WsClient.send_call(
        t.user_ws,
        "room:set_active_speaker",
        %{"active" => false}
      )

      WsClient.assert_frame(
        "room:speaking_update",
        %{"activeSpeakerMap" => map}
      )

      assert map == %{}

      assert MapSet.new([]) == Onion.RoomSession.get(room_id, :activeSpeakerMap)
    end
  end
end
