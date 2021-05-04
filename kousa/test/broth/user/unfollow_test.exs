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
    user_ws = WsClientFactory.create_client_for(user)

    {:ok, user: user, user_ws: user_ws}
  end

  describe "the user:unfollow operation" do
    test "causes you to to unfollow", t do
      followed = Factory.create(User)

      Beef.Follows.insert(%{
        userId: followed.id,
        followerId: t.user.id
      })

      assert Beef.Follows.following_me?(followed.id, t.user.id)

      ref =
        WsClient.send_call(t.user_ws, "user:unfollow", %{
          "userId" => followed.id
        })

      WsClient.assert_empty_reply(ref)

      refute Beef.Follows.following_me?(followed.id, t.user.id)
    end

    @tag :skip
    test "you can't follow yourself?"
  end
end
