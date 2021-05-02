defmodule BrothTest.User.GetFollowingTest do
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

  describe "the websocket user:get_following operation" do
    test "returns an empty list if you aren't following anyone", t do
      ref = WsClient.send_call(t.user_ws, "user:get_following", %{"cursor" => 0})

      WsClient.assert_reply("user:get_following:reply", ref, %{"following" => []})
    end

    test "returns that person if you are following someone", t do
      %{id: followed_id} = Factory.create(User)
      Kousa.Follow.follow(t.user.id, followed_id, true)

      ref = WsClient.send_call(t.user_ws, "user:get_following", %{"cursor" => 0})

      WsClient.assert_reply("user:get_following:reply", ref, %{
        "following" => [
          %{
            "id" => ^followed_id
          }
        ]
      })
    end

    test "can get following for someone else", t do
      %{id: follower_id, username: username} = Factory.create(User)
      Kousa.Follow.follow(follower_id, t.user.id, true)

      ref =
        WsClient.send_call(t.user_ws, "user:get_following", %{
          "cursor" => 0,
          "username" => username
        })

      user_id = t.user.id

      WsClient.assert_reply("user:get_following:reply", ref, %{
        "following" => [
          %{
            "id" => ^user_id
          }
        ]
      })
    end

    @tag :skip
    test "test proper pagination of user:get_following"
  end
end
