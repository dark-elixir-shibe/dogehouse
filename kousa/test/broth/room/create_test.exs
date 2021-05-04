defmodule BrothTest.Room.CreateTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Schemas.ScheduledRoom
  alias Beef.Users
  alias Beef.ScheduledRooms
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    user_ws = WsClientFactory.create_client_for(user)

    {:ok, user: user, user_ws: user_ws}
  end

  describe "the websocket room:create operation" do
    test "joins the user to the room", t do
      user_id = t.user.id

      ref =
        WsClient.send_call(
          t.user_ws,
          "room:create",
          %{
            "name" => "foo room",
            "description" => "baz quux",
            "isPrivate" => true
          }
        )

      WsClient.assert_reply(
        ref,
        %{
          "creatorId" => ^user_id,
          "description" => "baz quux",
          "id" => room_id,
          "name" => "foo room",
          "isPrivate" => true
        }
      )

      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)
    end

    test "can go without passing description", t do
      user_id = t.user.id

      ref =
        WsClient.send_call(
          t.user_ws,
          "room:create",
          %{
            "name" => "foo room",
            "isPrivate" => true
          }
        )

      WsClient.assert_reply(
        ref,
        %{
          "creatorId" => ^user_id,
          "description" => "",
          "id" => room_id,
          "name" => "foo room",
          "isPrivate" => true
        }
      )

      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)
    end

    test "can pass scheduled room id", t do
      user_id = t.user.id
      scheduled_room = Factory.create(ScheduledRoom, creatorId: user_id)

      ref =
        WsClient.send_call(
          t.user_ws,
          "room:create",
          %{
            "name" => "foo room",
            "description" => nil,
            "scheduledRoomId" => scheduled_room.id
          }
        )

      WsClient.assert_reply(
        ref,
        %{
          "creatorId" => ^user_id,
          "description" => "",
          "id" => room_id,
          "name" => "foo room",
          "isPrivate" => false
        }
      )

      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)

      assert %ScheduledRoom{started: true, roomId: ^room_id} =
               ScheduledRooms.get_by_id(scheduled_room.id)
    end

    test "can pass invitations to users"
  end
end
