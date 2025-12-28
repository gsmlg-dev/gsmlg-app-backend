defmodule GsmlgAppAdminWeb.Session.Store do
  @moduledoc """
  ETS-based session store owner with automatic expiration cleanup.

  This GenServer owns an ETS table that Plug.Session.ETS uses for session storage.
  Only the session ID is stored in the client cookie, while all session
  data remains in ETS.

  ## Data Format

  Sessions are stored by Plug.Session.ETS in the format:
  `{sid :: String.t, data :: map, timestamp :: :erlang.timestamp}`

  The timestamp is updated by Plug.Session.ETS on every read/write and
  is used by this module to detect and clean up expired sessions.

  ## Configuration

  - Session TTL: 8 hours (configurable via application config)
  - Cleanup interval: 5 minutes
  - Table options: :set, :public, :named_table with read_concurrency

  ## Usage

  The store is automatically started as part of the application supervision tree.
  Session operations are performed by Plug.Session.ETS directly on the ETS table.
  This GenServer handles table ownership and cleanup of expired sessions.
  """
  use GenServer
  require Logger

  @table_name :gsmlg_admin_sessions
  @cleanup_interval :timer.minutes(5)
  @default_session_ttl_seconds 8 * 60 * 60

  # Client API

  @doc """
  Starts the session store GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the ETS table name for direct access.
  """
  def table_name, do: @table_name

  @doc """
  Returns the count of all sessions in the table.

  Note: This counts all sessions regardless of expiration status.
  Expired sessions are cleaned up periodically by the cleanup process.
  """
  def count do
    :ets.info(@table_name, :size)
  rescue
    ArgumentError -> 0
  end

  @doc """
  Returns the count of active (non-expired) sessions.
  """
  def count_active do
    ttl_seconds = session_ttl_seconds()
    now = :erlang.timestamp()

    :ets.foldl(
      fn record, acc ->
        if not expired?(record, now, ttl_seconds), do: acc + 1, else: acc
      end,
      0,
      @table_name
    )
  rescue
    ArgumentError -> 0
  end

  @doc """
  Manually triggers cleanup of expired sessions.
  Returns the count of cleaned up sessions.
  """
  def cleanup do
    GenServer.call(__MODULE__, :cleanup)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    Logger.info("Session store initialized with table: #{@table_name}")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    count = cleanup_expired()
    {:reply, count, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    count = cleanup_expired()

    if count > 0 do
      Logger.info("Cleaned up #{count} expired session(s)")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  # Check if a session record is expired based on the Plug.Session.ETS format
  # Record format: {sid, data, timestamp}
  defp expired?(record, now, ttl_seconds) do
    case record do
      {_sid, _data, timestamp} when is_tuple(timestamp) and tuple_size(timestamp) == 3 ->
        session_time = timestamp_to_seconds(timestamp)
        now_seconds = timestamp_to_seconds(now)
        now_seconds - session_time > ttl_seconds

      # Unknown format, don't expire
      _ ->
        false
    end
  end

  defp timestamp_to_seconds({mega, sec, _micro}) do
    mega * 1_000_000 + sec
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    ttl_seconds = session_ttl_seconds()
    now = :erlang.timestamp()

    expired_ids =
      :ets.foldl(
        fn record, acc ->
          case record do
            {sid, _data, _timestamp} ->
              if expired?(record, now, ttl_seconds), do: [sid | acc], else: acc

            _ ->
              acc
          end
        end,
        [],
        @table_name
      )

    Enum.each(expired_ids, fn sid ->
      :ets.delete(@table_name, sid)
      Logger.debug("Session expired and deleted: #{String.slice(sid, 0..20)}...")
    end)

    length(expired_ids)
  rescue
    ArgumentError -> 0
  end

  defp session_ttl_seconds do
    Application.get_env(:gsmlg_app_admin_web, :session_ttl_seconds, @default_session_ttl_seconds)
  end
end
