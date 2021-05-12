defmodule BrothTest.Room.UnbanTest do
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

  describe "the websocket room:unban operation" do
    test "unbans that person from a room", t do
      # first, create a room owned by the test user.
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a blocked user that is logged in.
      %{id: banned_id} = Factory.create(User)

      Beef.Rooms.ban(room_id, banned_id, modId: t.user.id)

      assert Beef.Rooms.banned?(room_id, banned_id)

      # block the person.
      ref =
        WsClient.send_call(
          t.user_ws,
          "room:unban",
          %{"userId" => banned_id}
        )

      WsClient.assert_empty_reply(ref)

      refute Beef.Rooms.banned?(room_id, banned_id)
    end
  end
end
