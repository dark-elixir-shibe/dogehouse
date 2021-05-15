defmodule BrothTest.User.UnfollowTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    followed = Factory.create(User)

    Beef.Users.follow(user.id, followed.id)

    user_ws = WsClientFactory.create_client_for(user)

    {:ok, user: user, user_ws: user_ws, followed: followed}
  end

  describe "the user:unfollow operation" do
    test "causes you to to unfollow", t do

      assert Beef.Users.follows?(t.user.id, t.followed.id)

      ref =
        WsClient.send_call(t.user_ws, "user:unfollow", %{
          "userId" => t.followed.id
        })

      WsClient.assert_empty_reply(ref)

      refute Beef.Users.follows?(t.user.id, t.followed.id)
    end
  end
end
