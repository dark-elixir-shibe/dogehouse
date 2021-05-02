defmodule BrothTest.CreateRoomTest do
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

  describe "the websocket create_room operation" do
    test "creates a new room", t do
      user_id = t.user.id

      ref =
        WsClient.send_call_legacy(
          t.user_ws,
          "create_room",
          %{
            "name" => "foo room",
            "description" => "baz quux",
            "privacy" => "private"
          }
        )

      WsClient.assert_reply_legacy(
        ref,
        %{
          "room" => %{
            "creatorId" => ^user_id,
            "description" => "baz quux",
            "id" => room_id,
            "name" => "foo room",
            "isPrivate" => true
          }
        }
      )

      assert %{currentRoomId: ^room_id} = Users.get_by_id(user_id)
    end
  end

  test "creates a new room with an invitation"
end
