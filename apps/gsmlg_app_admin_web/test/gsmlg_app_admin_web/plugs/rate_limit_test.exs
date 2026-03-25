defmodule GsmlgAppAdminWeb.Plugs.RateLimitTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias GsmlgAppAdminWeb.Plugs.RateLimit

  setup do
    # Ensure ETS table exists and is clean
    if :ets.whereis(:api_gateway_rate_limits) != :undefined do
      :ets.delete_all_objects(:api_gateway_rate_limits)
    end

    # Use a unique key ID per test to avoid cross-test contamination
    key_id = "test-key-#{System.unique_integer([:positive])}"

    fake_api_key = %{
      id: key_id,
      rate_limit_rpm: 3,
      rate_limit_rpd: 100
    }

    {:ok, api_key: fake_api_key}
  end

  describe "call/2" do
    test "passes through when no api_key assigned" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> RateLimit.call(RateLimit.init([]))

      refute conn.halted
    end

    test "passes through when under rate limit", %{api_key: api_key} do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      refute conn.halted
    end

    test "returns 429 when RPM limit exceeded", %{api_key: api_key} do
      # Make requests up to the RPM limit
      for _ <- 1..3 do
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))
      end

      # The next request should be rate limited
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      assert conn.status == 429
      assert conn.halted
      assert get_resp_header(conn, "retry-after") != []

      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "rate_limit_error"
    end

    test "includes X-RateLimit-* headers on successful requests", %{api_key: api_key} do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      refute conn.halted
      assert ["3"] = get_resp_header(conn, "x-ratelimit-limit")
      assert ["2"] = get_resp_header(conn, "x-ratelimit-remaining")
      assert [_reset] = get_resp_header(conn, "x-ratelimit-reset")
    end

    test "remaining count decreases with each request", %{api_key: api_key} do
      conn1 =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      conn2 =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      [remaining1] = get_resp_header(conn1, "x-ratelimit-remaining")
      [remaining2] = get_resp_header(conn2, "x-ratelimit-remaining")

      assert String.to_integer(remaining1) > String.to_integer(remaining2)
    end

    test "includes X-RateLimit-* headers on 429 responses", %{api_key: api_key} do
      for _ <- 1..3 do
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))
      end

      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      assert conn.status == 429
      assert ["3"] = get_resp_header(conn, "x-ratelimit-limit")
      assert ["0"] = get_resp_header(conn, "x-ratelimit-remaining")
    end
  end
end
