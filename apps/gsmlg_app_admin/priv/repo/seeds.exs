# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     GsmlgAppAdmin.Repo.insert!(%GsmlgAppAdmin.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias GsmlgAppAdmin.Accounts.User

# Create admin user if it doesn't exist
admin_email = "admin@gsmlg.dev"
admin_password = "Qwer1234"

IO.puts("Creating admin user...")

# Check if admin user already exists
require Ash.Query

case User |> Ash.Query.filter(email == ^admin_email) |> Ash.read_one(authorize?: false) do
  {:ok, nil} ->
    IO.puts("Admin user not found, creating new one...")

    # Hash the password using bcrypt
    hashed_password = Bcrypt.hash_pwd_salt(admin_password)

    admin_user = %{
      email: admin_email,
      hashed_password: hashed_password,
      first_name: "Admin",
      last_name: "User",
      username: "admin",
      display_name: "Administrator",
      status: :active,
      email_verified: true,
      email_verified_at: DateTime.utc_now(),
      role: :admin,
      is_admin: true,
      timezone: "UTC",
      language: "en"
    }

    user = Ash.create!(User, admin_user, action: :seed_admin, authorize?: false)
    IO.puts("✅ Admin user created successfully!")
    IO.puts("   Email: #{user.email}")
    IO.puts("   Username: #{user.username}")
    IO.puts("   Role: #{user.role}")
    IO.puts("   Password: #{admin_password}")

  {:ok, user} ->
    IO.puts("✅ Admin user already exists:")
    IO.puts("   Email: #{user.email}")
    IO.puts("   Username: #{user.username}")
    IO.puts("   Role: #{user.role}")

  {:error, error} ->
    IO.puts("❌ Error checking for existing admin user:")
    IO.inspect(error)
end

IO.puts("Seed completed!")

# Seed initial apps
IO.puts("\n--- Seeding Apps ---")

alias GsmlgAppAdmin.Apps
alias GsmlgAppAdmin.Apps.App

apps_data = [
  %{
    name: "GeoIP Lookup",
    label: "geoip_lookup",
    short_description: "Find geography location of IP Address with precision and accuracy.",
    long_description:
      "See data source location of web requests and analyze network traffic patterns.",
    icon_path: "/images/icons/geoip_lookup.png",
    platforms: [:ios, :android],
    category: :network,
    display_order: 1,
    is_active: true,
    store_links: [
      %{store_type: :appstore, url: "https://apps.apple.com/cn/app/geoip-lookup/id1672850313"},
      %{
        store_type: :playstore,
        url: "https://play.google.com/store/apps/details?id=com.gsmlg.geoip_lookup"
      }
    ]
  },
  %{
    name: "Whois Lookup",
    label: "whois_lookup",
    short_description: "Find registrant information of domain, IP or AS numbers instantly.",
    long_description:
      "Get comprehensive information about your domain, IP or AS with detailed reports.",
    icon_path: "/images/icons/whois_lookup.png",
    platforms: [:ios, :android],
    category: :network,
    display_order: 2,
    is_active: true,
    store_links: [
      %{
        store_type: :appstore,
        url: "https://apps.apple.com/cn/app/lookup-whois-info/id6446807576"
      },
      %{
        store_type: :playstore,
        url: "https://play.google.com/store/apps/details?id=com.gsmlg.whois_lookup"
      }
    ]
  },
  %{
    name: "Simple Mirror",
    label: "simple_mirror",
    short_description: "Check your reflection anytime, anywhere with our premium mirror app!",
    long_description: "Easy to use, completely private, and absolutely free with no ads.",
    icon_path: "/images/icons/simple_mirror.png",
    platforms: [:android],
    category: :utility,
    display_order: 3,
    is_active: true,
    store_links: [
      %{
        store_type: :playstore,
        url: "https://play.google.com/store/apps/details?id=com.gsmlg.mirror"
      }
    ]
  },
  %{
    name: "YellowDog DNS",
    label: "yellowdog_dns",
    short_description: "Query custom DNS queries and all types of resource records!",
    long_description:
      "Run comprehensive DNS benchmarks to determine the performance of DNS servers.",
    icon_path: "/images/icons/yellowdog_dns.png",
    platforms: [:android],
    category: :network,
    display_order: 4,
    is_active: true,
    store_links: [
      %{
        store_type: :playstore,
        url: "https://play.google.com/store/apps/details?id=com.gsmlg.yellowdog"
      }
    ]
  },
  %{
    name: "Semaphore Client",
    label: "semaphore_client",
    short_description: "Run Ansible tasks directly from your phone with full control.",
    long_description:
      "Configure and monitor ansible tasks with real-time updates and notifications.",
    icon_path: "/images/icons/semaphore_client.png",
    platforms: [:android, :ios],
    category: :development,
    display_order: 5,
    is_active: true,
    store_links: [
      %{
        store_type: :playstore,
        url: "https://play.google.com/store/apps/details?id=org.gsmlg.semaphore"
      },
      %{store_type: :fdroid, url: "https://f-droid.org/en/packages/org.gsmlg.semaphore/"},
      %{
        store_type: :appstore,
        url: "https://apps.apple.com/us/app/ansible-semaphore-client/id6458789575"
      }
    ]
  }
]

for app_data <- apps_data do
  {store_links_data, app_attrs} = Map.pop(app_data, :store_links)

  # Check if app already exists
  case App |> Ash.Query.filter(label == ^app_attrs.label) |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      IO.puts("Creating app: #{app_attrs.name}...")

      case Apps.create_app(app_attrs) do
        {:ok, app} ->
          # Create store links
          for {link_data, index} <- Enum.with_index(store_links_data) do
            Apps.create_store_link(Map.merge(link_data, %{app_id: app.id, display_order: index}))
          end

          IO.puts("  ✅ Created with #{length(store_links_data)} store links")

        {:error, error} ->
          IO.puts("  ❌ Error creating: #{inspect(error)}")
      end

    {:ok, _existing} ->
      IO.puts("✅ App already exists: #{app_attrs.name}")

    {:error, error} ->
      IO.puts("❌ Error checking app: #{inspect(error)}")
  end
end

IO.puts("\nApps seed completed!")
