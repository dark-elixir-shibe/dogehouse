defmodule BrothTest.Room.InviteTest do
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

  describe "the websocket room:invite operation" do
    test "invites that person to a room", t do
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a follower user that is logged in.
      follower = %{id: follower_id} = Factory.create(User)
      follower_ws = WsClientFactory.create_client_for(follower)

      WsClient.do_call(t.user_ws, "user:follow", %{"userId" => follower_id})

      ref = WsClient.send_call(t.user_ws, "room:invite", %{"userId" => follower_id})
      WsClient.assert_empty_reply(ref)

      # note this comes from the follower's client
      WsClient.assert_frame("room:invited", %{"roomId" => ^room_id}, follower_ws)
    end
  end
end
