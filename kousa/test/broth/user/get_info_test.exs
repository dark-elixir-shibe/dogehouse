defmodule BrothTest.User.GetInfoTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    user_ws = WsClientFactory.create_client_for(user)

    {:ok, user: user, user_ws: user_ws}
  end

  describe "the websocket user:get_info operation" do
    test "can get your own user info", t do
      user_id = t.user.id

      ref =
        WsClient.send_call(
          t.user_ws,
          "user:get_info",
          %{"userIdOrUsername" => t.user.id}
        )

      WsClient.assert_reply(ref, %{"id" => ^user_id})
    end

    test "you get nil back for username that doesn't exist", t do
      user_id = t.user.id

      ref =
        WsClient.send_call(
          t.user_ws,
          "user:get_info",
          %{"userIdOrUsername" => "aosifdjoqwejfoq"}
        )

      WsClient.assert_reply(ref, %{"error" => "could not find user"})
    end

    @tag :skip
    test "you can't stalk someone who has blocked you"
  end
end
