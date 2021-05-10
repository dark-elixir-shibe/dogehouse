defmodule Beef.Lenses.Users do
  alias Beef.Schemas.User
  alias Beef.Repo
  require Logger

  @spec room_auth(User.t()) :: Broth.Message.Types.RoomAuth
  def room_auth(%{id: id, currentRoom: %{creatorId: id}}), do: :owner
  def room_auth(%{roomPermissions: %{isMod: true}}), do: :mod

  def room_auth(user = %{currentRoom: %Ecto.Association.NotLoaded{}}) do
    Logger.warn("room_auth/1 called without a currentRoom preloaded")

    user
    |> Repo.preload(:currentRoom)
    |> room_auth
  end

  def room_auth(user = %{roomPermissions: %Ecto.Association.NotLoaded{}}) do
    Logger.warn("room_auth/1 called without roomPermissions preloaded")

    user
    |> Repo.preload(:roomPermissions)
    |> room_auth
  end

  def room_auth(_), do: :user

  @spec room_role(User.t()) :: Broth.Message.Types.RoomRole
  # currently the creator is always a speaker
  def room_role(%{id: id, currentRoom: %{creatorId: id}}), do: :speaker
  def room_role(%{roomPermissions: %{isSpeaker: true}}), do: :speaker
  def room_role(%{roomPermissions: %{askedToSpeak: true}}), do: :raised_hand

  def room_role(user = %{currentRoom: %Ecto.Association.NotLoaded{}}) do
    Logger.warn("room_role/1 called without a currentRoom preloaded")

    user
    |> Repo.preload(:currentRoom)
    |> room_role
  end

  def room_role(user = %{roomPermissions: %Ecto.Association.NotLoaded{}}) do
    Logger.warn("room_role/1 called without roomPermissions preloaded")

    user
    |> Repo.preload(:roomPermissions)
    |> room_role
  end

  def room_role(_), do: :listener

  def bot?(user), do: not is_nil(user.botOwnerId)
end
