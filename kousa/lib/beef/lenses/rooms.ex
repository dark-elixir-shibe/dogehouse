defmodule Beef.Lenses.Rooms do

  alias Beef.Schemas.Room
  alias Kousa.Utils.UUID

  @max_room_size Application.compile_env!(:kousa, :max_room_size)

  @spec can_join(nil | Room.t, UUID.t) :: :ok | {:error, String.t}
  def can_join(nil, _) do
    {:error, "room doesn't exist anymore"}
  end

  def can_join(%{attendees: attendees}, _) when length(attendees) >= @max_room_size do
    {:error, "room is full"}
  end

  def can_join(%{creator: %{blocks: blocks}, bans: bans}, user_id) do
    cond do
      user_id in blocks ->
        {:error, "the creator of the room has blocked you"}
      user_id in bans ->
        {:error, "you are banned from the room"}
    end
  end

  def can_join(_, _), do: :ok
end
