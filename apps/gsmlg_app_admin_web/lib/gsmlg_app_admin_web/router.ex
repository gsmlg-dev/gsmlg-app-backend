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
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:load_from_bearer, opt_app: :gsmlg_app_admin)
  end

  scope "/", GsmlgAppAdminWeb do
    pipe_through(:browser)

    sign_in_route(
      auth_routes_prefix: "/auth",
      register_path: "/register",
      reset_path: "/reset",
      otp_app: :gsmlg_app_admin,
      overrides: [GsmlgAppAdminWeb.AshOverrides]
    )
    sign_out_route AuthController
    # plug AshAuthentication.Plug, user: Accounts.User
    auth_routes_for GsmlgAppAdmin.Accounts.User, to: AuthController

    get("/", PageController, :home)

    auth_routes_for(GsmlgAppAdmin.Accounts.User, to: AuthController)
    reset_route(otp_app: :gsmlg_app_admin)
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
