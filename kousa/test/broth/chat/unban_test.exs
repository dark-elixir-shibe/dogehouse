defmodule BrothTest.Chat.UnbanTest do
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

  describe "the websocket chat:unban operation" do
    test "unbans the person from the room chat", t do
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      banned = %{id: banned_id} = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)

      # join the speaker user into the room
      WsClient.do_call(banned_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _)

      WsClient.do_call(t.user_ws, "chat:ban", %{"userId" => banned_id})
      WsClient.assert_frame("chat:banned", %{"userId" => ^banned_id}, t.user_ws)
      WsClient.assert_frame("chat:banned", %{"userId" => ^banned_id}, banned_ws)

      assert Onion.Chat.banned?(room_id, banned_id)

      ref = WsClient.send_call(t.user_ws, "chat:unban", %{"userId" => banned_id})
      WsClient.assert_empty_reply(ref)

      WsClient.assert_frame("chat:unbanned", %{"userId" => ^banned_id}, t.user_ws)

      refute Onion.Chat.banned?(room_id, banned_id)
    end

    @tag :skip
    test "a non-mod can't ban someone from room chat"
  end
end
