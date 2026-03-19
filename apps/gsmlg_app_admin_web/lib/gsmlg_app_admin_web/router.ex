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

      # AI Chat routes
      live "/chat", ChatLive.Index, :index
      live "/chat/:id", ChatLive.Index, :conversation

      # AI Provider module routes
      live "/ai-provider/providers", AiProviderLive.ProviderSettings.Index, :index
      live "/ai-provider/providers/new", AiProviderLive.ProviderSettings.Form, :new
      live "/ai-provider/providers/:id", AiProviderLive.ProviderSettings.Show, :show
      live "/ai-provider/providers/:id/edit", AiProviderLive.ProviderSettings.Form, :edit

      live "/ai-provider/api-keys", AiProviderLive.ApiKey.Index, :index
      live "/ai-provider/api-keys/new", AiProviderLive.ApiKey.Index, :new
      live "/ai-provider/api-keys/:id/edit", AiProviderLive.ApiKey.Index, :edit

      live "/ai-provider/system-prompts", AiProviderLive.SystemPrompt.Index, :index
      live "/ai-provider/system-prompts/new", AiProviderLive.SystemPrompt.Index, :new
      live "/ai-provider/system-prompts/:id/edit", AiProviderLive.SystemPrompt.Index, :edit

      live "/ai-provider/memories", AiProviderLive.Memory.Index, :index
      live "/ai-provider/memories/new", AiProviderLive.Memory.Index, :new
      live "/ai-provider/memories/:id/edit", AiProviderLive.Memory.Index, :edit

      live "/ai-provider/tools", AiProviderLive.Tool.Index, :index
      live "/ai-provider/tools/new", AiProviderLive.Tool.Index, :new
      live "/ai-provider/tools/:id/edit", AiProviderLive.Tool.Index, :edit

      live "/ai-provider/agents", AiProviderLive.Agent.Index, :index
      live "/ai-provider/agents/new", AiProviderLive.Agent.Index, :new
      live "/ai-provider/agents/:id/edit", AiProviderLive.Agent.Index, :edit

      live "/ai-provider/mcp-servers", AiProviderLive.McpServer.Index, :index
      live "/ai-provider/mcp-servers/new", AiProviderLive.McpServer.Index, :new
      live "/ai-provider/mcp-servers/:id/edit", AiProviderLive.McpServer.Index, :edit

      live "/ai-provider/usage", AiProviderLive.ApiUsage.Index, :index

      # User profile routes
      live "/profile", UserProfileLive.Index, :index
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
