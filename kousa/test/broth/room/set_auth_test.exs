defmodule BrothTest.Room.SetAuthTest do
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

  describe "the using room:set_auth with mod" do
    test "makes the person a mod", t do
      room_id = t.room_id

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}})

      # make the person a mod
      ref =
        WsClient.send_call(
          t.user_ws,
          "room:set_auth",
          %{
            "userId" => speaker_id,
            "level" => "mod"
          }
        )

      WsClient.assert_empty_reply(ref)

      # both clients get notified
      WsClient.assert_frame(
        "room:auth_update",
        %{"userId" => ^speaker_id, "level" => "mod", "roomId" => ^room_id},
        t.user_ws
      )

      WsClient.assert_frame(
        "room:auth_update",
        %{"userId" => ^speaker_id, "level" => "mod", "roomId" => ^room_id},
        speaker_ws
      )

      assert Beef.Users.get(speaker_id).roomPermissions.isMod
    end
  end

  describe "the set_auth command can" do
    test "transfer room_creator-ship", t do
      room_id = t.room_id

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}})

      # make the person a room creator.
      ref =
        WsClient.send_call(t.user_ws, "room:set_auth", %{
          "userId" => speaker_id,
          "level" => "owner"
        })

      WsClient.assert_empty_reply(ref)

      # NB: we get an extraneous speaker_added message here.
      WsClient.assert_frame(
        "room:auth_update",
        %{"userId" => ^speaker_id, "level" => "owner"}
      )

      assert Beef.Rooms.get(room_id).creatorId == speaker_id
      assert Process.alive?(t.user_ws)
    end

    @tag :skip
    test "a non-owner can't make someone a room creator"
  end
end
