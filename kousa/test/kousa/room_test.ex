defmodule KousaTest.RoomTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Schemas.Room
  alias KousaTest.Support.Factory
  alias Onion.RoomSession
  alias Onion.PubSub

  setup do
    user = Factory.create(User)
    {:ok, user: user}
  end

  describe "create_with/1" do
    test "creates a room by the user", %{user: user = %{id: user_id}} do
      PubSub.subscribe("room:*")

      assert {:ok, room, user!} = %Room{}
      |> Ecto.Changeset.change(%{name: "foo room", creatorId: user_id})
      |> Kousa.Room.create_with(user)

      assert user.id == room.creatorId

      # checks that a Onion.RoomSession process exists
      assert Onion.RoomSession.alive?(room.id)

      # checks that the user is in the room session
      assert %{attendees: attendees} = Onion.RoomSession.dump(room.id)
      assert user_id in attendees

      # checks that the user is in the room according to the database
      assert %{attendees: [%{id: ^user_id}]} = Beef.Rooms.get(room.id)
    end
  end
end
