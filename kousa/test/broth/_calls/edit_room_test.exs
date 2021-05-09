defmodule BrothTest.EditRoomTest do
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

  describe "the websocket edit_room operation" do
    test "changes the name of the room you're in", t do
      user_id = t.user.id
      # first, create a room owned by the primary user.
      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)

      ref =
        WsClient.send_call_legacy(
          t.user_ws,
          "edit_room",
          %{"name" => "bar room", "description" => "baz quux", "privacy" => "private"}
        )

      WsClient.assert_reply_legacy(
        ref,
        true,
        t.user_ws
      )

      WsClient.assert_frame_legacy(
        "new_room_details",
        %{
          "description" => "baz quux",
          "isPrivate" => true,
          "name" => "bar room",
          "roomId" => ^room_id
        }
      )

      # TODO: make sure that privacy is actually set
      assert %{
               isPrivate: true,
               description: "baz quux",
               name: "bar room"
             } = Beef.Rooms.get(room_id)
    end

    @tag :skip
    test "when you're not in a room", t do
      ref =
        WsClient.send_call_legacy(
          t.user_ws,
          "edit_room",
          %{}
        )

      WsClient.assert_reply_legacy(
        ref,
        _,
        t.user_ws
      )
    end

    @tag :skip
    test "errors when you aren't the creator of the room"

    @tag :skip
    test "when the room doesn't exist"
  end
end
