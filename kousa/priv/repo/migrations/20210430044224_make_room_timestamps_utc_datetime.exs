defmodule Beef.Repo.Migrations.MakeRoomTimestampsUtcDatetime do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      modify :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end
    alter table(:rooms) do
      modify :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      modify :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end
    alter table(:followers) do
      modify :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      modify :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end
  end
end
