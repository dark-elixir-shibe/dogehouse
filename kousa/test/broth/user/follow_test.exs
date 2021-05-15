defmodule BrothTest.User.FollowTest do
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

  describe "the user:follow operation" do
    test "causes you to follow", t do
      followed = Factory.create(User)

      refute Users.follows?(t.user.id, followed.id)

      ref =
        WsClient.send_call(t.user_ws, "user:follow", %{
          "userId" => followed.id
        })

      WsClient.assert_empty_reply(ref)

      assert Users.follows?(t.user.id, followed.id)
    end

    @tag :skip
    test "you can't follow yourself?"
  end
end
