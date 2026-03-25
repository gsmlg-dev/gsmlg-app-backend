defmodule GsmlgAppAdminWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :gsmlg_app_admin_web

  # Session stored server-side in ETS, only session ID in signed cookie.
  # ETS table owned by GsmlgAppAdminWeb.Session.Store GenServer.
  @session_options [
    store: :ets,
    table: :gsmlg_admin_sessions,
    key: "_gsmlg_app_admin_web_key",
    signing_salt: "Zq8+Jo4s",
    same_site: "Lax",
    http_only: true,
    secure: Mix.env() == :prod,
    max_age: 8 * 60 * 60
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:uri, session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :gsmlg_app_admin_web,
    gzip: false,
    only: GsmlgAppAdminWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :gsmlg_app_admin_web
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 10_485_760

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug GsmlgAppAdminWeb.Router

  @doc """
  Wraps the default call/2 to catch stale CSRF tokens and redirect to sign-in.

  When a LiveView sign-in form submits via `phx-trigger-action` after the
  session has expired or the server restarted, the CSRF token in the form
  no longer matches the session. Instead of showing an error page, redirect
  back to sign-in so the user gets a fresh form.
  """
  @impl true
  def call(conn, opts) do
    super(conn, opts)
  rescue
    Plug.CSRFProtection.InvalidCSRFTokenError ->
      conn
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.put_session(:phoenix_flash, %{"error" => "Session expired, please try again."})
      |> Phoenix.Controller.redirect(to: "/sign-in")
      |> Plug.Conn.halt()
  end
end
