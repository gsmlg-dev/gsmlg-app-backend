defmodule GsmlgAppAdminWeb.Router do
  use GsmlgAppAdminWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {GsmlgAppAdminWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:load_from_session, otp_app: :gsmlg_app_admin)
    plug(GsmlgAppAdminWeb.Plugs.SessionUser)
    plug(GsmlgAppAdminWeb.Plugs.StoreReturnTo)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:load_from_bearer, opt_app: :gsmlg_app_admin)
  end

  pipeline :require_auth do
    plug(GsmlgAppAdminWeb.Plugs.RequireAuth)
  end

  # Public API routes (no authentication required)
  scope "/api", GsmlgAppAdminWeb.Api do
    pipe_through(:api)

    get "/apps", AppsController, :index
  end

  # Public authentication routes
  scope "/", GsmlgAppAdminWeb do
    pipe_through(:browser)

    sign_in_route(
      auth_routes_prefix: "/auth",
      register_path: "/register",
      reset_path: "/reset",
      otp_app: :gsmlg_app_admin,
      overrides: [GsmlgAppAdminWeb.AshOverrides]
    )

    sign_out_route(AuthController)
    auth_routes_for(GsmlgAppAdmin.Accounts.User, to: AuthController)
    reset_route(otp_app: :gsmlg_app_admin)
  end

  # Protected controller routes
  scope "/", GsmlgAppAdminWeb do
    pipe_through([:browser, :require_auth])

    get("/", PageController, :home)
  end

  scope "/", GsmlgAppAdminWeb do
    pipe_through(:browser)

    live_session :authenticated,
      layout: {GsmlgAppAdminWeb.Layouts, :app},
      on_mount: [
        {AshAuthentication.Phoenix.LiveSession, {:set_otp_app, :gsmlg_app_admin}},
        {AshAuthentication.Phoenix.LiveSession, :default},
        {GsmlgAppAdminWeb.LiveUserAuth, :live_user_required}
      ] do
      # User management routes
      live "/users", UserManagementLive.Index, :index
      live "/users/new", UserManagementLive.Index, :new
      live "/users/:id/edit", UserManagementLive.Index, :edit

      # Apps management routes
      live "/apps", AppsManagementLive.Index, :index
      live "/apps/new", AppsManagementLive.Form, :new
      live "/apps/:id/edit", AppsManagementLive.Form, :edit

      # Provider Settings routes (must be before /chat/:id to avoid matching "settings" as an ID)
      live "/chat/settings", ProviderSettingsLive.Index, :index
      live "/chat/settings/new", ProviderSettingsLive.Form, :new
      live "/chat/settings/:id", ProviderSettingsLive.Show, :show
      live "/chat/settings/:id/edit", ProviderSettingsLive.Form, :edit

      # AI Chat routes
      live "/chat", ChatLive.Index, :index
      live "/chat/:id", ChatLive.Index, :conversation
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gsmlg_app_admin_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: GsmlgAppAdminWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
