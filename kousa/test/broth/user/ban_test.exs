defmodule BrothTest.User.BanTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Users
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  @ben_github_id Application.compile_env!(:kousa, :ben_github_id)

  setup do
    user = Factory.create(User, githubId: @ben_github_id)
    user_ws = WsClientFactory.create_client_for(user)

    {:ok, user: user, user_ws: user_ws}
  end

  describe "the websocket user:ban operation" do
    test "doesn't work for not-ben awad" do
      notben = Factory.create(User)
      notben_ws = WsClientFactory.create_client_for(notben)

      banned = Factory.create(User)
      WsClientFactory.create_client_for(banned)

      ref =
        WsClient.send_call(notben_ws, "user:ban", %{
          "userId" => banned.id,
          "reason" => "you're a douche"
        })

      WsClient.assert_error(ref, %{"message" => message})
      assert message =~ "but that user didn't exist"
    end

    test "works for ben awad", t do
      banned = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)

      ref =
        WsClient.send_call(t.user_ws, "user:ban", %{
          "userId" => banned.id,
          "reason" => "you're a douche"
        })

      WsClient.assert_empty_reply(ref)

      # this frame is targetted to the banned user
      WsClient.assert_frame_legacy("banned", _, banned_ws)

      # check that the user has been updated.
      assert %{reasonForBan: "you're a douche"} = Users.get_by_id(banned.id)
    end

    test "will destroy a room if they are alone", t do
      banned = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)

      %{"id" => room_id} =
        WsClient.do_call(
          banned_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      WsClient.do_call(t.user_ws, "user:ban", %{
        "userId" => banned.id,
        "reason" => "you're a douche"
      })

      # note: targeted to banned_ws
      WsClient.assert_frame_legacy("banned", _, banned_ws)

      # check that the room is gone.
      refute Beef.Rooms.get(room_id)
    end

    test "will eject a user from a room if they aren't alone", t do
      safe = %{id: safe_id} = Factory.create(User)
      safe_ws = WsClientFactory.create_client_for(safe)

      %{"id" => room_id} =
        WsClient.do_call(
          safe_ws,
          "room:create",
          %{"name" => "foo room", "description" => "foo"}
        )

      # create and join the banned user to the room
      banned = Factory.create(User)
      banned_ws = WsClientFactory.create_client_for(banned)
      WsClient.do_call(banned_ws, "room:join", %{"roomId" => room_id})
      WsClient.assert_frame("room:joined", _, safe_ws)

      assert %{attendees: [_, _]} = Beef.Rooms.get(room_id)

      WsClient.do_call(t.user_ws, "user:ban", %{
        "userId" => banned.id,
        "reason" => "you're a douche"
      })

      # check that the room is still there and the safe user is there
      assert %{attendees: [%{id: ^safe_id}]} = Beef.Rooms.get(room_id)
    end
  end
end
