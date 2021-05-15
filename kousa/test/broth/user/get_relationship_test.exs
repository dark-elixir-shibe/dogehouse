defmodule BrothTest.User.GetRelationshipTest do
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

  describe "the websocket user:get_relationship operation" do
    test "retrieves symmetric following info", t do
      user_id = t.user.id

      followed = %{id: followed_id} = Factory.create(User)
      followed_ws = WsClientFactory.create_client_for(followed)

      ref =
        WsClient.send_call(
          t.user_ws,
          "user:get_relationship",
          %{"userId" => user_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => "self"})

      ref =
        WsClient.send_call(
          t.user_ws,
          "user:get_relationship",
          %{"userId" => followed_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => nil})

      ref =
        WsClient.send_call(
          followed_ws,
          "user:get_relationship",
          %{"userId" => user_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => nil})

      WsClient.do_call(t.user_ws, "user:follow", %{"userId" => followed_id})
      WsClient.do_call(followed_ws, "user:follow", %{"userId" => t.user.id})

      ref =
        WsClient.send_call(
          t.user_ws,
          "user:get_relationship",
          %{"userId" => followed_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => "mutual"})

      ref =
        WsClient.send_call(
          followed_ws,
          "user:get_relationship",
          %{"userId" => user_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => "mutual"})
    end

    test "retrieves asymmetric following info", t do
      user_id = t.user.id

      followed = %{id: followed_id} = Factory.create(User)
      followed_ws = WsClientFactory.create_client_for(followed)

      WsClient.do_call(t.user_ws, "user:follow", %{"userId" => followed_id})

      ref =
        WsClient.send_call(
          t.user_ws,
          "user:get_relationship",
          %{"userId" => followed_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => "following"})

      ref =
        WsClient.send_call(
          followed_ws,
          "user:get_relationship",
          %{"userId" => user_id}
        )

      WsClient.assert_reply(ref, %{"relationship" => "follower"})
    end
  end
end
