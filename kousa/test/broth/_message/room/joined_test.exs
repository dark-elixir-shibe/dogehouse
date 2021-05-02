defmodule BrothTest.Message.Room.JoinedTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias KousaTest.Support.Factory

  test "the joined struct encodes correctly" do
    user = %{id: user_id} = Factory.create(Beef.Schemas.User)
    mute_uuid = UUID.uuid4()
    deaf_uuid = UUID.uuid4()

    msg = %Broth.Message.Room.Joined{
      user: user,
      muteMap: MapSet.new([mute_uuid]),
      deafMap: MapSet.new([deaf_uuid])}

      assert %{"user" => %{"id" => ^user_id}, "muteMap" => %{^mute_uuid => true}, "deafMap" => %{^deaf_uuid => true}}
        = Jason.decode!(Jason.encode!(msg))
  end
end
