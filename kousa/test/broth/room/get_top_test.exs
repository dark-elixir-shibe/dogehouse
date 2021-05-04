defmodule BrothTest.Room.GetTopTest do
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

  describe "the websocket room:get_top operation" do
    test "returns one public room if it's the only one", t do
      user_id = t.user.id

      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)

      ref =
        WsClient.send_call(
          t.user_ws,
          "room:get_top",
          %{}
        )

      WsClient.assert_reply(ref, %{"rooms" => [%{"id" => ^room_id}]})
    end

    test "doesn't return a room if it's private", t do
      user_id = t.user.id

      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo", "isPrivate" => true}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)

      ref =
        WsClient.send_call(
          t.user_ws,
          "room:get_top",
          %{}
        )

      WsClient.assert_reply(ref, %{"rooms" => []})
    end

    @tag :skip
    test "when there's more than one room"

    @tag :skip
    test "cursors also work"

    @tag :skip
    test "there is a maximum limit to the cursor"
  end
end
