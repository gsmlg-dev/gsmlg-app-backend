defmodule GsmlgAppAdminWeb.Plugs.RateLimit do
  @moduledoc """
  ETS-based sliding window rate limiter for API gateway requests.
  Per-key RPM/RPD limits. Returns HTTP 429 with `Retry-After` header on exceed.
  """

  import Plug.Conn

  @behaviour Plug

  @ets_table :api_gateway_rate_limits

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    ensure_ets_table()

    api_key = conn.assigns[:api_key]

    if api_key do
      rpm_limit = api_key.rate_limit_rpm || default_rpm()
      rpd_limit = api_key.rate_limit_rpd || default_rpd()

      now = System.system_time(:second)
      key_id = api_key.id

      rpm_count = count_requests(key_id, :minute, now, 60)
      rpd_count = count_requests(key_id, :day, now, 86_400)

      cond do
        rpm_count >= rpm_limit ->
          retry_after = 60 - rem(now, 60)

          rate_limit_response(
            conn,
            retry_after,
            "Rate limit exceeded: #{rpm_limit} requests per minute."
          )

        rpd_count >= rpd_limit ->
          retry_after = 86_400 - rem(now, 86_400)

          rate_limit_response(
            conn,
            retry_after,
            "Rate limit exceeded: #{rpd_limit} requests per day."
          )

        true ->
          record_request(key_id, now)
          conn
      end
    else
      conn
    end
  end

  defp rate_limit_response(conn, retry_after, message) do
    conn
    |> put_resp_header("retry-after", to_string(retry_after))
    |> put_resp_content_type("application/json")
    |> send_resp(
      429,
      Jason.encode!(%{
        error: %{
          message: message,
          type: "rate_limit_error",
          code: "rate_limit_exceeded"
        }
      })
    )
    |> halt()
  end

  defp ensure_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      try do
        :ets.new(@ets_table, [:named_table, :public, :duplicate_bag])
      rescue
        ArgumentError -> :ok
      end
    end
  end

  defp count_requests(key_id, window, now, window_seconds) do
    cutoff = now - window_seconds
    match_spec = [{{key_id, window, :"$1"}, [{:>, :"$1", cutoff}], [true]}]

    :ets.select_count(@ets_table, match_spec)
  end

  defp record_request(key_id, now) do
    :ets.insert(@ets_table, {key_id, :minute, now})
    :ets.insert(@ets_table, {key_id, :day, now})

    # Cleanup old entries periodically (1% chance per request)
    if :rand.uniform(100) == 1 do
      cleanup_old_entries(now)
    end
  end

  defp cleanup_old_entries(now) do
    minute_cutoff = now - 120
    day_cutoff = now - 172_800

    try do
      :ets.select_delete(@ets_table, [
        {{:_, :minute, :"$1"}, [{:<, :"$1", minute_cutoff}], [true]}
      ])

      :ets.select_delete(@ets_table, [
        {{:_, :day, :"$1"}, [{:<, :"$1", day_cutoff}], [true]}
      ])
    rescue
      _ -> :ok
    end
  end

  defp default_rpm do
    Application.get_env(:gsmlg_app_admin, GsmlgAppAdmin.AI.Gateway, [])
    |> Keyword.get(:default_rate_limit_rpm, 60)
  end

  defp default_rpd do
    Application.get_env(:gsmlg_app_admin, GsmlgAppAdmin.AI.Gateway, [])
    |> Keyword.get(:default_rate_limit_rpd, 1000)
  end
end
