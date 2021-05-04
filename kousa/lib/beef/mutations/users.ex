defmodule Beef.Mutations.Users do
  import Ecto.Query, warn: false
  import Kousa.Utils.UUID, only: [is_uuid: 1]

  alias Beef.Repo
  alias Beef.Schemas.User
  alias Beef.Queries.Users, as: Query
  alias Beef.RoomPermissions

  alias Ecto.Multi

  # create-update-delete BASICS
  def update(user, data) do
    user
    |> User.changeset(data)
    |> Repo.update()
  end

  def delete(user_id) do
    %User{id: user_id} |> Repo.delete()
  end

  # SPECIFIC MUTATIONS
  def join_room(user, room_id, opts) do
    perms! = if opts[:speaker], do: %{isSpeaker: true}, else: %{}
    perms! = Map.merge(perms!, %{roomId: room_id, userId: user.id})

    user
    |> User.join_room_changeset(room_id, perms!)
    |> Repo.update()
    |> case do
      {:ok, user} ->
        {:ok, Repo.preload(user, [:currentRoom, :roomPermissions])}

      error ->
        error
    end
  end

  @changes %{
    # auth changes
    user: %{isMod: false},
    mod: %{isMod: true},
    # role changes
    speaker: %{isSpeaker: true, askedToSpeak: false},
    raised_hand: %{isSpeaker: false, askedToSpeak: true},
    listener: %{isSpeaker: false, askedToSpeak: false}
  }

  def set_auth(user, auth), do: set_perms(user, auth)
  def set_role(user, level), do: set_perms(user, level)

  def set_perms(user = %User{}, value) do
    user
    |> User.change_perms(@changes[value])
    |> Repo.update()
  end

  def set_perms(user_id, value) when is_uuid(user_id) do
    Multi.new()
    |> Multi.run(:fetch, &multi_fetch_user(&1, &2, user_id))
    |> Multi.update(:update, &User.change_perms(&1.fetch, @changes[value]))
    |> Repo.transaction()
    |> case do
      {:ok, multi} -> {:ok, multi.update}
      error -> error
    end
  end

  defp multi_fetch_user(_repo, _, user_id) do
    case Beef.Users.get(user_id) do
      nil -> {:error, "not present"}
      user -> {:ok, user}
    end
  end

  ########################################################################

  def bulk_insert(users) do
    Repo.insert_all(
      User,
      users,
      on_conflict: :nothing
    )
  end

  def inc_num_following(user_id, n) do
    Query.start()
    |> Query.filter_by_id(user_id)
    |> Query.inc_num_following_by_n(n)
    |> Repo.update_all([])
  end

  def set_reason_for_ban(user_id, reason_for_ban) do
    Query.start()
    |> Query.filter_by_id(user_id)
    |> Query.update_reason_for_ban(reason_for_ban)
    |> Repo.update_all([])
  end

  def set_ip(user_id, ip) do
    Query.start()
    |> Query.filter_by_id(user_id)
    |> Query.update_set_ip(ip)
    |> Repo.update_all([])
  end

  def set_online(user_id) do
    Query.start()
    |> Query.filter_by_id(user_id)
    |> Query.update_set_online_true()
    |> Repo.update_all([])
  end

  def set_user_left_current_room(user_id) do
    Onion.UserSession.set_current_room_id(user_id, nil)

    Query.start()
    |> Query.filter_by_id(user_id)
    |> Query.update_set_current_room_nil()
    |> Repo.update_all([])
  end

  def set_offline(user_id) do
    Query.start()
    |> Query.filter_by_id(user_id)
    |> Query.update_set_online_false()
    |> Query.update_set_last_online_to_now()
    |> Repo.update_all([])
  end

  def set_current_room(user_id, room_id, can_speak \\ false, returning \\ false) do
    roomPermissions =
      case can_speak do
        true ->
          case RoomPermissions.set_speaker(user_id, room_id, true, true) do
            {:ok, x} -> x
            _ -> nil
          end

        _ ->
          RoomPermissions.get(user_id, room_id)
      end

    Onion.UserSession.set_current_room_id(user_id, room_id)

    q =
      from(u in User,
        where: u.id == ^user_id,
        update: [
          set: [
            currentRoomId: ^room_id
          ]
        ]
      )

    q = if returning, do: select(q, [u], u), else: q

    case Repo.update_all(q, []) do
      {_, [user]} -> %{user | roomPermissions: roomPermissions}
      _ -> nil
    end
  end

  def twitter_find_or_create(user) do
    db_user =
      from(u in User,
        where: u.twitterId == ^user.twitterId,
        limit: 1
      )
      |> Repo.one()

    if db_user do
      if is_nil(db_user.twitterId) do
        from(u in User,
          where: u.id == ^db_user.id,
          update: [
            set: [
              twitterId: ^user.twitterId
            ]
          ]
        )
        |> Repo.update_all([])
      end

      {:find, db_user}
    else
      {:create,
       Repo.insert!(
         %User{
           username: Kousa.Utils.Random.big_ascii_id(),
           email: if(user.email == "", do: nil, else: user.email),
           twitterId: user.twitterId,
           avatarUrl: user.avatarUrl,
           bannerUrl: user.bannerUrl,
           displayName:
             if(is_nil(user.displayName) or String.trim(user.displayName) == "",
               do: "Novice Doge",
               else: user.displayName
             ),
           bio: user.bio,
           hasLoggedIn: true
         },
         returning: true
       )}
    end
  end

  def github_find_or_create(user, github_access_token) do
    githubId = Integer.to_string(user["id"])

    db_user =
      from(u in User,
        where: u.githubId == ^githubId,
        limit: 1
      )
      |> Repo.one()

    if db_user do
      if is_nil(db_user.githubId) do
        from(u in User,
          where: u.id == ^db_user.id,
          update: [
            set: [
              githubId: ^githubId,
              githubAccessToken: ^github_access_token
            ]
          ]
        )
        |> Repo.update_all([])
      end

      {:find, db_user}
    else
      {:create,
       Repo.insert!(
         %User{
           username: Kousa.Utils.Random.big_ascii_id(),
           githubId: githubId,
           email: if(user["email"] == "", do: nil, else: user["email"]),
           githubAccessToken: github_access_token,
           avatarUrl: user["avatar_url"],
           bannerUrl: user["banner_url"],
           displayName:
             if(is_nil(user["name"]) or String.trim(user["name"]) == "",
               do: "Novice Doge",
               else: user["name"]
             ),
           bio: user["bio"],
           hasLoggedIn: true
         },
         returning: true
       )}
    end
  end

  def discord_find_or_create(user, discord_access_token) do
    discordId = user["id"]

    db_user =
      from(u in User,
        where: u.discordId == ^discordId,
        limit: 1
      )
      |> Repo.one()

    if db_user do
      if is_nil(db_user.discordId) do
        from(u in User,
          where: u.id == ^db_user.id,
          update: [
            set: [
              discordId: ^discordId,
              discordAccessToken: ^discord_access_token
            ]
          ]
        )
        |> Repo.update_all([])
      end

      {:find, db_user}
    else
      {:create,
       Repo.insert!(
         %User{
           username: Kousa.Utils.Random.big_ascii_id(),
           discordId: discordId,
           email: if(user["email"] == "", do: nil, else: user["email"]),
           discordAccessToken: discord_access_token,
           avatarUrl: Kousa.Discord.get_avatar_url(user),
           displayName: user["username"],
           hasLoggedIn: true
         },
         returning: true
       )}
    end
  end

  def create_bot(owner_id, username) do
    %User{}
    |> User.edit_changeset(%{
      id: Ecto.UUID.generate(),
      username: username,
      # @todo pick better default
      avatarUrl: "https://pbs.twimg.com/profile_images/1384417471944290304/4epg3HTW_400x400.jpg",
      displayName: username,
      botOwnerId: owner_id,
      bio: "I am a bot",
      apiKey: Ecto.UUID.generate()
    })
    |> Repo.insert(returning: true)
  end
end
