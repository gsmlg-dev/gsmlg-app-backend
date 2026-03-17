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

  pipeline :api_gateway do
    plug(:accepts, ["json"])
    plug(GsmlgAppAdminWeb.Plugs.CORS)
    plug(GsmlgAppAdminWeb.Plugs.ApiKeyAuth)
    plug(GsmlgAppAdminWeb.Plugs.RateLimit)
  end

  # Public API routes (no authentication required)
  scope "/api", GsmlgAppAdminWeb.Api do
    pipe_through(:api)

    get "/apps", AppsController, :index
  end

  # AI Gateway API routes (API key authenticated)
  scope "/api/v1", GsmlgAppAdminWeb.Api.V1 do
    pipe_through(:api_gateway)

    # OpenAI-compatible endpoints
    post "/chat/completions", ChatCompletionsController, :create
    get "/models", ModelsController, :index

    # Anthropic-compatible endpoint
    post "/messages", MessagesController, :create

    # Image generation
    post "/images/generations", ImagesController, :create

    # OCR
    post "/ocr", OcrController, :create

    # Agent endpoints
    post "/agents/:agent_slug/chat", AgentController, :chat
    get "/agents", AgentController, :index
    get "/agents/:agent_slug", AgentController, :show
    get "/agents/:agent_slug/tools", AgentController, :tools
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

      # API Gateway management routes
      live "/api-keys", ApiKeyLive.Index, :index
      live "/api-keys/new", ApiKeyLive.Index, :new
      live "/api-keys/:id/edit", ApiKeyLive.Index, :edit

      live "/system-prompts", SystemPromptLive.Index, :index
      live "/system-prompts/new", SystemPromptLive.Index, :new
      live "/system-prompts/:id/edit", SystemPromptLive.Index, :edit

      live "/memories", MemoryLive.Index, :index
      live "/memories/new", MemoryLive.Index, :new
      live "/memories/:id/edit", MemoryLive.Index, :edit

      live "/tools", ToolLive.Index, :index
      live "/tools/new", ToolLive.Index, :new
      live "/tools/:id/edit", ToolLive.Index, :edit

      live "/agents", AgentLive.Index, :index
      live "/agents/new", AgentLive.Index, :new
      live "/agents/:id/edit", AgentLive.Index, :edit

      live "/mcp-servers", McpServerLive.Index, :index
      live "/mcp-servers/new", McpServerLive.Index, :new
      live "/mcp-servers/:id/edit", McpServerLive.Index, :edit

      live "/api-usage", ApiUsageLive.Index, :index
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
