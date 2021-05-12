defmodule Beef.Mutations.RoomBlocks do
  import Ecto.Query

  alias Beef.Repo
  alias Beef.Schemas.RoomBlock

  def ban(room_id, user_id, opts) do
    %RoomBlock{}
    |> RoomBlock.changeset(%{roomId: room_id, userId: user_id, modId: opts[:modId]})
    |> Repo.insert()
  end

  def unban(room_id, user_id) do
    from(rb in RoomBlock,
      where: rb.roomId == ^room_id and rb.userId == ^user_id
    )
    |> Repo.delete_all()
  end
end
