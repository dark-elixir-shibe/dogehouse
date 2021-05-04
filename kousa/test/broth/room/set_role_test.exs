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
    test "takes a speaker and turns them into listener", t do
      room_id = t.room_id

      # create a speaker user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _)

      WsClient.do_call(t.user_ws, "room:set_role", %{"userId" => speaker_id, "role" => "speaker"})
      WsClient.assert_frame("room:role_update", x)

      assert :speaker == speaker_id |> Users.get() |> Users.room_role()

      WsClient.send_call(t.user_ws, "room:set_role", %{
        "userId" => speaker_id,
        "role" => "listener"
      })

      WsClient.assert_frame(
        "room:role_update",
        %{"role" => "listener", "userId" => ^speaker_id},
        t.user_ws
      )

      WsClient.assert_frame(
        "room:role_update",
        %{"role" => "listener", "userId" => ^speaker_id},
        speaker_ws
      )

      assert :listener == speaker_id |> Users.get() |> Users.room_role()
    end

    @tag :skip
    test "you can make yourself a listener"

    @tag :skip
    test "you can't make someone a listener unless you're a mod"

    @tag :skip
    test "mods can't make owners listeners"
  end

  describe "when you set_role to speaker" do
    test "makes the person a speaker", t do
      room_id = t.room_id

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _)

      assert :listener == speaker_id |> Users.get() |> Users.room_role()

      # add the person as a speaker.
      ref =
        WsClient.send_call(
          t.user_ws,
          "room:set_role",
          %{"userId" => speaker_id, "role" => "speaker"}
        )

      WsClient.assert_empty_reply("room:set_role:reply", ref)

      # both clients get notified
      WsClient.assert_frame(
        "room:role_update",
        %{"userId" => ^speaker_id, "role" => "speaker"},
        t.user_ws
      )

      WsClient.assert_frame(
        "room:role_update",
        %{"userId" => ^speaker_id, "role" => "speaker"},
        speaker_ws
      )

      assert :speaker == speaker_id |> Users.get() |> Users.room_role()
    end

    test "ask to speak makes you a speaker when auto speaker is on", t do
      room_id = t.room_id
      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      assert :listener == speaker_id |> Users.get() |> Users.room_role()

      ref = WsClient.send_call(speaker_ws, "room:set_role", %{"role" => "raised_hand"})
      WsClient.assert_empty_reply("room:set_role:reply", ref)

      WsClient.assert_frame("user:update", _)
      assert :raised_hand == speaker_id |> Users.get() |> Users.room_role()

      # both clients get notified
      WsClient.assert_frame(
        "room:role_update",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        t.user_ws
      )

      WsClient.assert_frame(
        "room:role_update",
        %{"userId" => ^speaker_id, "roomId" => ^room_id},
        speaker_ws
      )
    end

    test "owner can make them a speaker", t do
      room_id = t.room_id
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      refute :speaker == speaker.id |> Beef.Users.get() |> Beef.Users.room_role()

      # join the speaker user into the room
      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})

      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}})

      # add the person as a speaker.
      ref =
        WsClient.send_call(
          t.user_ws,
          "room:set_role",
          %{"userId" => speaker_id, "role" => "speaker"}
        )

      WsClient.assert_empty_reply(ref)
      assert :speaker == speaker.id |> Beef.Users.get() |> Beef.Users.room_role()
    end

    test "mod can make the person a speaker", t do
      room_id = t.room_id

      # create mod
      mod = %{id: mod_id} = Factory.create(User)
      mod_ws = WsClientFactory.create_client_for(mod)
      WsClient.do_call(mod_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^mod_id}}, t.user_ws)

      WsClient.do_call(t.user_ws, "room:set_auth", %{"userId" => mod_id, "level" => "mod"})
      WsClient.assert_frame("room:auth_update", _, t.user_ws)
      WsClient.assert_frame("room:auth_update", _, mod_ws)

      # create a user that is logged in.
      speaker = %{id: speaker_id} = Factory.create(User)
      speaker_ws = WsClientFactory.create_client_for(speaker)

      WsClient.do_call(speaker_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}}, t.user_ws)
      WsClient.assert_frame("room:joined", %{"user" => %{"id" => ^speaker_id}}, mod_ws)

      # add the person as a speaker.
      ref =
        WsClient.send_call(
          mod_ws,
          "room:set_role",
          %{"userId" => speaker_id, "role" => "speaker"}
        )

      WsClient.assert_empty_reply(ref)

      WsClient.assert_frame("user:update", _, speaker_ws)

      assert :speaker = speaker_id |> Users.get() |> Users.room_role()

      # both clients get notified
      WsClient.assert_frame(
        "room:role_update",
        %{"userId" => ^speaker_id, "role" => "speaker"},
        mod_ws
      )

      WsClient.assert_frame(
        "room:role_update",
        %{"userId" => ^speaker_id, "role" => "speaker"},
        speaker_ws
      )
    end

    @tag :skip
    test "you can't make a person a speaker if you aren't a mod"
  end
end
