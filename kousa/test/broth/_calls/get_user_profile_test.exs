defmodule BrothTest.GetUserProfileTest do
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

  describe "the websocket get_user_profile operation" do
    test "can get your own user info", t do
      user_id = t.user.id

      ref =
        WsClient.send_call_legacy(
          t.user_ws,
          "get_user_profile",
          %{"userId" => t.user.id}
        )

      WsClient.assert_reply_legacy(
        ref,
        %{
          "id" => ^user_id
        }
      )
    end

    @tag :skip
    test "you can't stalk someone who has blocked you"
  end
end
