defmodule Beef.Queries.Rooms do
  import Ecto.Query, except: [preload: 2]
  alias Beef.Schemas.Room

  def start do
    from(r in Room)
  end

  def preload(query, :attendees) do
    Ecto.Query.preload(query, :attendees)
  end

  def filter_by(query, filters) do
    Enum.reduce(filters, query, fn
      {:id, room_id}, query -> where(query, [r], r.id == ^room_id)
      {:creatorId, user_id}, query -> where(query, [r], r.creatorId == ^user_id)
    end)
  end

  def limit_one(query) do
    limit(query, [r], 1)
  end

end
