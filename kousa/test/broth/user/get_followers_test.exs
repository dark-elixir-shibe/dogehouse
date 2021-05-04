defmodule BrothTest.User.GetFollowersTest do
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

  describe "the websocket user:get_followers operation" do
    test "returns an empty list if no one is following you", t do
      ref = WsClient.send_call(t.user_ws, "user:get_followers", %{"cursor" => 0})

      WsClient.assert_reply(ref, %{"followers" => []})
    end

    test "returns that person if someone is following you", t do
      %{id: follower_id} = Factory.create(User)
      Kousa.Follow.follow(follower_id, t.user.id, true)

      ref =
        WsClient.send_call(t.user_ws, "user:get_followers", %{
          "cursor" => 0
        })

      WsClient.assert_reply(ref, %{
        "followers" => [
          %{
            "id" => ^follower_id
          }
        ]
      })
    end

    test "can get followers for someone else", t do
      %{id: following_id, username: username} = Factory.create(User)
      Kousa.Follow.follow(t.user.id, following_id, true)

      ref =
        WsClient.send_call(t.user_ws, "user:get_followers", %{
          "cursor" => 0,
          "username" => username
        })

      user_id = t.user.id

      WsClient.assert_reply(ref, %{
        "followers" => [
          %{
            "id" => ^user_id
          }
        ]
      })
    end

    @tag :skip
    test "you can't stalk someone who has blocked you"

    @tag :skip
    test "test proper pagination of user:get_following"
  end
end
