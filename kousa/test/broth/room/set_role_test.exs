defmodule BrothTest.Room.SetRoleTest do
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

    %{"id" => room_id} = WsClient.do_call(user_ws, "room:create", %{"name" => "room"})

    {:ok, user: user, user_ws: user_ws, room_id: room_id}
  end

  describe "for when you room:set_role to listener" do
    test "takes a speaker and turns them into lister", t do
      room_id = t.room_id

      # create a speaker user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame_legacy("new_user_join_room", _)

      Beef.RoomPermissions.set_speaker(t.user.id, room_id, true)

      assert Beef.RoomPermissions.speaker?(t.user.id, room_id)

      WsClient.send_msg(t.user_ws, "room:set_role", %{
        "userId" => speaker_id,
        "role" => "listener"
      })

      WsClient.assert_frame_legacy(
        "speaker_removed",
        %{"roomId" => ^room_id, "userId" => ^speaker_id},
        t.user_ws
      )

      WsClient.assert_frame_legacy(
        "speaker_removed",
        %{"roomId" => ^room_id, "userId" => ^speaker_id},
        speaker_ws
      )

      refute Beef.RoomPermissions.speaker?(speaker_id, room_id)
    end

    @tag :skip
    test "you can make yourself a listener"

    @tag :skip
    test "you can't make someone a listener unless you're a mod"
  end

  describe "when you set_role to speaker" do
    test "makes the person a speaker", t do
      room_id = t.room_id

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      refute Beef.RoomPermissions.speaker?(speaker_id, room_id)
      Kousa.Room.set_role(speaker_id, :raised_hand, by: t.user.id)
      assert Beef.RoomPermissions.asked_to_speak?(speaker_id, room_id)

      WsClient.assert_frame_legacy("new_user_join_room", %{"user" => %{"id" => ^speaker_id}})

      # add the person as a speaker.
      WsClient.send_msg(
        t.user_ws,
        "room:set_role",
        %{"userId" => speaker_id, "role" => "speaker"}
      )

      # both clients get notified
      WsClient.assert_frame_legacy(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        t.user_ws
      )

      WsClient.assert_frame_legacy(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        speaker_ws
      )

      assert Beef.RoomPermissions.speaker?(speaker_id, room_id)
    end

    test "ask to speak makes you a speaker when auto speaker is on", t do
      room_id = t.room_id
      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      refute Beef.RoomPermissions.speaker?(speaker_id, room_id)
      Kousa.Room.set_role(speaker_id, :raised_hand, by: t.user.id)

      # both clients get notified
      WsClient.assert_frame_legacy(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        t.user_ws
      )

      WsClient.assert_frame_legacy(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        speaker_ws
      )

      assert Beef.RoomPermissions.speaker?(speaker_id, room_id)
    end

    test "can only make them a speaker if they asked to speak", t do
      room_id = t.room_id
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      refute Beef.RoomPermissions.speaker?(speaker.id, room_id)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}})

      # add the person as a speaker.
      WsClient.send_msg(
        t.user_ws,
        "room:set_role",
        %{"userId" => speaker_id, "role" => "speaker"}
      )

      refute Beef.RoomPermissions.speaker?(speaker_id, room_id)
    end

    test "mod can make the person a speaker", t do
      room_id = t.room_id

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}}, t.user_ws)

      # create mod
      mod = %{id: mod_id} = Factory.create(User)
      mod_ws = WsClientFactory.create_client_for(mod)
      WsClient.do_call(mod_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^mod_id}}, t.user_ws)
      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^mod_id}}, speaker_ws)

      IO.puts("===============================")
      WsClient.do_call(t.user_ws, "room:set_auth", %{"userId" => mod_ws, "level" => "mod"})

      # add the person as a speaker.
      WsClient.send_msg(
        mod_ws,
        "room:set_role",
        %{"userId" => speaker_id, "role" => "speaker"}
      )

      # both clients get notified
      WsClient.assert_frame_legacy(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        mod_ws
      )

      WsClient.assert_frame_legacy(
        "speaker_added",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        speaker_ws
      )

      assert Beef.RoomPermissions.speaker?(speaker_id, room_id)
    end

    @tag :skip
    test "you can't make a person a speaker if you aren't a mod"
  end
end
