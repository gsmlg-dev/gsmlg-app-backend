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

    test "returns 429 when RPD limit exceeded" do
      key_id = "rpd-test-key-#{System.unique_integer([:positive])}"

      api_key = %{
        id: key_id,
        rate_limit_rpm: 1000,
        rate_limit_rpd: 2
      }

      for _ <- 1..2 do
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))
      end

      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      assert conn.status == 429
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "per day"
    end

    test "429 response body has correct error structure", %{api_key: api_key} do
      for _ <- 1..3 do
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))
      end

      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "rate_limit_error"
      assert body["error"]["message"] =~ "per minute"
    end

    test "different keys have independent rate limits" do
      key1 = %{
        id: "independent-key1-#{System.unique_integer([:positive])}",
        rate_limit_rpm: 1,
        rate_limit_rpd: 100
      }

      key2 = %{
        id: "independent-key2-#{System.unique_integer([:positive])}",
        rate_limit_rpm: 1,
        rate_limit_rpd: 100
      }

      # Exhaust key1's limit
      conn(:post, "/api/v1/chat/completions")
      |> assign(:api_key, key1)
      |> RateLimit.call(RateLimit.init([]))

      # key1 should be rate limited
      conn1 =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, key1)
        |> RateLimit.call(RateLimit.init([]))

      assert conn1.status == 429

      # key2 should still pass
      conn2 =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, key2)
        |> RateLimit.call(RateLimit.init([]))

      refute conn2.halted
    end

    test "returns OpenAI error format for /chat/completions path", %{api_key: api_key} do
      for _ <- 1..3 do
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))
      end

      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, api_key)
        |> RateLimit.call(RateLimit.init([]))

      body = Jason.decode!(conn.resp_body)
      # OpenAI format: no top-level "type" key
      assert body["error"]["type"] == "rate_limit_error"
      refute Map.has_key?(body, "type")
    end

    test "returns Anthropic error format for /messages path" do
      key = %{
        id: "anthropic-rate-key-#{System.unique_integer([:positive])}",
        rate_limit_rpm: 1,
        rate_limit_rpd: 100
      }

      conn(:post, "/api/v1/messages")
      |> assign(:api_key, key)
      |> RateLimit.call(RateLimit.init([]))

      conn =
        conn(:post, "/api/v1/messages")
        |> assign(:api_key, key)
        |> RateLimit.call(RateLimit.init([]))

      assert conn.status == 429
      body = Jason.decode!(conn.resp_body)
      # Anthropic format: top-level "type" = "error"
      assert body["type"] == "error"
      assert body["error"]["type"] == "rate_limit_error"
    end

    test "uses system defaults when key has nil rate limits" do
      key = %{
        id: "nil-limits-key-#{System.unique_integer([:positive])}",
        rate_limit_rpm: nil,
        rate_limit_rpd: nil
      }

      conn =
        conn(:post, "/api/v1/chat/completions")
        |> assign(:api_key, key)
        |> RateLimit.call(RateLimit.init([]))

      refute conn.halted
      # Default RPM is 60; remaining should be 59
      [limit] = get_resp_header(conn, "x-ratelimit-limit")
      assert String.to_integer(limit) == 60
    end
  end
end
