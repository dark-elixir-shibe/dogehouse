defmodule Kousa.User do
  alias Beef.Users
  alias Onion.PubSub

  def delete(user_id) do
    Kousa.Room.leave(user_id)
    Users.delete(user_id)
  end

  def update_with(changeset = %Ecto.Changeset{}) do
    case Users.update(changeset) do
      {:ok, user} ->
        # TODO: clean this up by making Onion.UserSession adopt the User schema and having it
        # accept pubsub broadcast messages.

        Onion.UserSession.set_state(
          user.id,
          %{
            display_name: user.displayName,
            username: user.username,
            avatar_url: user.avatarUrl,
            banner_url: user.bannerUrl
          }
        )

        PubSub.broadcast("user:" <> user.id, user)
        {:ok, user}

      {:error, %Ecto.Changeset{errors: [username: {"has already been taken, _"}]}} ->
        {:error, "that user name is taken"}

      error ->
        error
    end
  end

  @doc """
  bans a user from the platform.  Must be an admin operator (currently ben) to run
  this function.  Authorization passed in via the opts (:admin_id) field.

  If someone that isn't ben tries to use it, it won't leak a meaningful error message
  (to prevent side channel knowledge of authorization status)
  """
  def ban(user_id_to_ban, reason_for_ban, opts) do
    authorized_github_id = Application.get_env(:kousa, :ben_github_id, "")

    case Users.get(opts[:admin_id]) do
      %{githubId: ^authorized_github_id} ->
        user = Users.get(user_id_to_ban)
        Kousa.Room.leave(user)
        Users.set_reason_for_ban(user_id_to_ban, reason_for_ban)
        PubSub.broadcast("user:" <> user_id_to_ban, %Broth.Message.User.Banned{})
        :ok
      _ -> {:error, "tried to ban #{user_id_to_ban} but that user didn't exist"}
    end
  end

  def create_bot(user, botname) do
    with false <- Users.bot?(user),
         bots when length(bots) <= 100 <- user.bots,
         {:ok, bot_user} <- Users.create_bot(user, botname) do
      # TODO: broadcast new state
      {:ok, bot_user.apiKey, %{user | bots: [bot_user | user.bots]}}
    else
      true -> {:error, "bots can't create bots"}
      count when is_integer(count) -> {:error, "you've reached the max of 100 bot accounts"}
      error -> error
    end
  end
end
