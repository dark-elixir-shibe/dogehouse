defmodule BrothTest.Room.GetInfoTest do
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

  describe "the websocket room:get_info operation" do
    test "can get your own user info", t do
      room_id = t.room_id

      ref = WsClient.send_call(t.user_ws, "room:get_info", %{"id" => room_id})

      WsClient.assert_reply(ref, %{"id" => ^room_id, "name" => "foo room"})
    end

    test "if you don't supply id, then you'll get the room you're in", t do
      room_id = t.room_id

      ref =
        WsClient.send_call(
          t.user_ws,
          "room:get_info",
          %{}
        )

      WsClient.assert_reply(ref, %{"id" => ^room_id, "name" => "foo room"})
    end

    @tag :skip
    test "what happens if you aren't in a room and supply room id"

    @tag :skip
    test "what happens when you try to do room id of a private room"
  end
end
