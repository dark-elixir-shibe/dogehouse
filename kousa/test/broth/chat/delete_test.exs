defmodule BrothTest.Chat.DeleteTest do
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

  describe "the websocket chat:delete operation" do
    test "sends a message to the room", t do
      user_id = t.user.id

      %{"id" => room_id} =
        WsClient.do_call(
          t.user_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      listener = %{id: listener_id} = Factory.create(User)
      listener_ws = WsClientFactory.create_client_for(listener)

      # join the speaker user into the room
      WsClient.do_call(listener_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame_legacy("new_user_join_room", _)

      # note that an asynchronous delete request doesn't really have
      # to make sense to anyone.
      msg_id = UUID.uuid4()

      WsClient.send_msg(t.user_ws, "chat:delete", %{
        "messageId" => msg_id,
        "userId" => listener_id
      })

      WsClient.assert_frame(
        "chat:delete",
        %{
          "deleterId" => ^user_id,
          "messageId" => ^msg_id,
          "userId" => ^listener_id
        },
        t.user_ws
      )

      WsClient.assert_frame(
        "chat:delete",
        %{
          "deleterId" => ^user_id,
          "messageId" => ^msg_id,
          "userId" => ^listener_id
        },
        listener_ws
      )
    end
  end
end
