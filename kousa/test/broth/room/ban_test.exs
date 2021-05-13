defmodule BrothTest.Room.BanTest do
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

    {:ok, user: user, user_ws: user_ws}
  end

  describe "the websocket room:ban operation" do
    test "blocks that person from a room", t do
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a banned user that is logged in.
      banned = %{id: banned_id} = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)

      # join the banned user into the room
      WsClient.do_call(banned_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _)

      # block the person.
      ref = WsClient.send_call(t.user_ws, "room:ban", %{"userId" => banned_id})
      WsClient.assert_empty_reply(ref)

      WsClient.assert_frame("room:left", %{"userId" => ^banned_id}, t.user_ws)

      assert Beef.Rooms.banned?(room_id, banned_id)
    end

    test "blocks person's ip from a room", t do
      # first, create a room owned by the test user.
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a banned user that is logged in.
      banned = %{id: banned_id} = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)
      # make sure ip got saved
      %User{ip: str_ip} = Users.get_by_id(banned.id)
      refute is_nil(str_ip)

      # join the banned user into the room
      WsClient.do_call(banned_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _)

      # block the person.
      ref = WsClient.send_call(t.user_ws, "room:ban", %{"userId" => banned_id, "shouldBanIp" => true})
      WsClient.assert_empty_reply(ref)

      WsClient.assert_frame(
        "room:left",
        %{"userId" => ^banned_id},
        t.user_ws
      )

      flunk "this isn't quite working"

      assert Beef.Rooms.banned?(room_id, banned_id)
      also_banned = Factory.create(User)
      WsClientFactory.create_client_for(also_banned)
      assert Beef.Rooms.banned?(room_id, also_banned.id)
    end

    test "block then block person's ip from a room", t do
      # first, create a room owned by the test user.
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # create a banned user that is logged in.
      banned = %{id: banned_id} = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)
      # make sure ip got saved
      %User{ip: str_ip} = Users.get_by_id(banned.id)
      refute is_nil(str_ip)

      # join the banned user into the room
      WsClient.do_call(banned_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _)

      ref = WsClient.send_call(t.user_ws, "room:ban", %{"userId" => banned_id})
      WsClient.assert_empty_reply(ref)

      WsClient.assert_frame(
        "room:left",
        %{"userId" => ^banned_id},
        t.user_ws
      )

      flunk "we gotta get this working elsewise."

      assert Beef.Rooms.banned?(room_id, banned_id)
      also_banned = Factory.create(User)
      WsClientFactory.create_client_for(also_banned)
      assert Beef.Rooms.banned?(room_id, also_banned.id)
    end
  end
end
