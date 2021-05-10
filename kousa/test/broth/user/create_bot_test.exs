defmodule BrothTest.User.CreateBotTest do
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

  describe "the websocket user:create_bot operation" do
    test "creates new user with username", t do
      ref =
        WsClient.send_call(
          t.user_ws,
          "user:create_bot",
          %{
            "username" => "qowidjoqwd"
          }
        )

      WsClient.assert_reply(ref, %{"apiKey" => api_key})

      assert Kousa.Utils.UUID.valid?(api_key)
      assert %{bots: [%{apiKey: ^api_key}]} = Users.get(t.user.id)
    end

    test "returns error for username that's already taken", t do
      ref =
        WsClient.send_call(
          t.user_ws,
          "user:create_bot",
          %{
            "username" => t.user.username
          }
        )

      WsClient.assert_error(ref, %{"username" => "has already been taken"})
    end

    test "bot accounts can't create bot accounts", t do
      ref =
        WsClient.send_call(
          t.user_ws,
          "user:create_bot",
          %{
            "username" => "oqieuoqw"
          }
        )

      WsClient.assert_reply(ref, %{"apiKey" => api_key})
      %{bots: [bot]} = Users.get(t.user.id)
      bot_ws = WsClientFactory.create_client_for(bot)

      ref =
        WsClient.send_call(
          bot_ws,
          "user:create_bot",
          %{
            "username" => "qowidjoqwdqwe"
          }
        )

      WsClient.assert_error(ref, %{"message" => "bots can't create bots"})
    end
  end
end
