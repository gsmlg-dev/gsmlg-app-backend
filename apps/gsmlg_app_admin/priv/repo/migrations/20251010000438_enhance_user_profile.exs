defmodule GsmlgAppAdmin.Repo.Migrations.EnhanceUserProfile do
  @moduledoc """
  Enhances the users table with additional profile fields, status management,
  roles, and audit capabilities for a comprehensive user management system.
  """

  use Ecto.Migration

  def up do
    # Create custom enum types
    execute("CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending')")
    execute("CREATE TYPE user_role AS ENUM ('admin', 'user', 'moderator')")

    # Add new columns to users table
    alter table(:users) do
      # Basic profile fields
      add(:first_name, :string)
      add(:last_name, :string)
      add(:username, :string)
      add(:display_name, :string)

      # User status and verification
      add(:status, :user_status, default: "active", null: false)
      add(:email_verified, :boolean, default: false, null: false)
      add(:email_verified_at, :utc_datetime_usec)

      # Security and audit fields
      add(:last_login_at, :utc_datetime_usec)
      add(:failed_login_attempts, :integer, default: 0, null: false)
      add(:locked_until, :utc_datetime_usec)

      # Role and permissions
      add(:role, :user_role, default: "user", null: false)
      add(:is_admin, :boolean, default: false, null: false)

      # User preferences
      add(:timezone, :string, default: "UTC", null: false)
      add(:language, :string, default: "en", null: false)
    end

    # Add indexes for performance and querying
    create(unique_index(:users, [:username], name: "users_unique_username_index"))
    create(index(:users, [:status], name: "users_status_index"))
    create(index(:users, [:role], name: "users_role_index"))
    create(index(:users, [:email_verified], name: "users_email_verified_index"))
    create(index(:users, [:is_admin], name: "users_is_admin_index"))
  end

  def down do
    # Drop indexes
    drop_if_exists(index(:users, [:is_admin], name: "users_is_admin_index"))
    drop_if_exists(index(:users, [:email_verified], name: "users_email_verified_index"))
    drop_if_exists(index(:users, [:role], name: "users_role_index"))
    drop_if_exists(index(:users, [:status], name: "users_status_index"))
    drop_if_exists(unique_index(:users, [:username], name: "users_unique_username_index"))

    # Remove columns
    alter table(:users) do
      remove(:timezone)
      remove(:language)
      remove(:is_admin)
      remove(:role)
      remove(:locked_until)
      remove(:failed_login_attempts)
      remove(:last_login_at)
      remove(:email_verified_at)
      remove(:email_verified)
      remove(:status)
      remove(:display_name)
      remove(:username)
      remove(:last_name)
      remove(:first_name)
    end

    # Drop custom enum types
    execute("DROP TYPE IF EXISTS user_role")
    execute("DROP TYPE IF EXISTS user_status")
  end
end
