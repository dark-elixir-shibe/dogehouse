defmodule Beef.Lenses.Rooms do
  require Logger
  alias Beef.Repo
  alias Beef.Schemas.Room
  alias Kousa.Utils.UUID

  @max_room_size Application.compile_env!(:kousa, :max_room_size)

  @spec can_join(nil | Room.t(), UUID.t()) :: :ok | {:error, String.t()}
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

  @spec count_attendees(Room.t()) :: non_neg_integer
  def count_attendees(%{attendees: list}) when is_list(list) do
    length(list)
  end

  def count_attendees(room = %{attendees: %Ecto.Association.NotLoaded{}}) do
    Logger.warn("Rooms.count_attendees/1 called without preloading attendees")

    room
    |> Repo.preload(:attendees)
    |> count_attendees
  end
end
