defmodule GsmlgAppAdminWeb.Plugs.ApiKeyAuthTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  describe "has_scope?/2" do
    test "returns true when scope is present" do
      api_key = %{scopes: [:chat_completions, :messages]}
      assert ApiKeyAuth.has_scope?(api_key, :chat_completions)
      assert ApiKeyAuth.has_scope?(api_key, :messages)
    end

    test "returns false when scope is missing" do
      api_key = %{scopes: [:chat_completions]}
      refute ApiKeyAuth.has_scope?(api_key, :images)
    end

    test "handles nil scopes" do
      api_key = %{scopes: nil}
      refute ApiKeyAuth.has_scope?(api_key, :chat_completions)
    end

    test "returns false when scopes list is empty" do
      api_key = %{scopes: []}
      refute ApiKeyAuth.has_scope?(api_key, :chat_completions)
    end

    test "atom scope does not match string scope" do
      # Scopes are stored as atoms; string keys should not grant access
      api_key = %{scopes: [:chat_completions]}
      refute ApiKeyAuth.has_scope?(api_key, "chat_completions")
    end
  end

  describe "call/2 - key extraction" do
    test "returns 401 when no API key header is present" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.status == 401
      assert conn.halted

      body = Jason.decode!(conn.resp_body)
      assert body["error"]["type"] == "authentication_error"
      assert body["error"]["message"] =~ "Missing API key"
    end

    test "returns 401 for short API keys" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> put_req_header("authorization", "Bearer short")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.status == 401
      assert conn.halted

      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "Invalid API key"
    end

    test "returns 401 for invalid API key via x-api-key header" do
      conn =
        conn(:post, "/api/v1/chat/completions")
        |> put_req_header("x-api-key", "gsk_not_a_real_key_at_all_1234567890abcdef")
        |> ApiKeyAuth.call(ApiKeyAuth.init([]))

      assert conn.status == 401
      assert conn.halted
    end
  end
end

defmodule GsmlgAppAdminWeb.Plugs.ApiKeyAuthIntegrationTest do
  @moduledoc """
  Database-backed integration tests for ApiKeyAuth plug.
  Verifies expired keys, revoked keys, hash verification, and successful auth.
  """

  use GsmlgAppAdminWeb.ConnCase

  alias GsmlgAppAdmin.AI.ApiKey
  alias GsmlgAppAdminWeb.Plugs.ApiKeyAuth

  defp create_user do
    uid = :erlang.unique_integer([:positive])

    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "plugtest#{uid}@example.com",
        password: "StrongPass123!"
      })
      |> Ash.create(authorize?: false)

    user
  end

  defp create_api_key(attrs \\ %{}) do
    user = create_user()

    defaults = %{
      name: "test-key-#{:erlang.unique_integer([:positive])}",
      scopes: [:chat_completions, :models_list],
      is_active: true,
      user_id: user.id
    }

    {:ok, api_key} =
      ApiKey
      |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
      |> Ash.create(authorize?: false)

    {api_key.__raw_key__, api_key, user}
  end

  defp call_plug(conn) do
    ApiKeyAuth.call(conn, ApiKeyAuth.init([]))
  end

  describe "expired keys" do
    test "returns 401 for expired key", %{conn: conn} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      {raw_key, _api_key, _user} = create_api_key(%{expires_at: past})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "expired"
    end

    test "succeeds for key with future expiry", %{conn: conn} do
      future = DateTime.add(DateTime.utc_now(), 86_400, :second)
      {raw_key, _api_key, _user} = create_api_key(%{expires_at: future})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> call_plug()

      refute conn.halted
      assert conn.assigns[:api_key]
    end

    test "succeeds for key with nil expiry", %{conn: conn} do
      {raw_key, _api_key, _user} = create_api_key(%{expires_at: nil})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> call_plug()

      refute conn.halted
      assert conn.assigns[:api_key]
    end
  end

  describe "revoked keys" do
    test "returns 401 for revoked key", %{conn: conn} do
      {raw_key, api_key, _user} = create_api_key()

      api_key
      |> Ash.Changeset.for_update(:revoke, %{})
      |> Ash.update!(authorize?: false)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "revoked"
    end

    test "returns 401 for key created inactive", %{conn: conn} do
      {raw_key, _api_key, _user} = create_api_key(%{is_active: false})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "revoked"
    end
  end

  describe "hash verification" do
    test "returns 401 when prefix matches but hash does not", %{conn: conn} do
      {raw_key, _api_key, _user} = create_api_key()
      prefix = String.slice(raw_key, 0, 8)
      tampered_key = prefix <> String.duplicate("A", 44)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{tampered_key}")
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"]["message"] =~ "Invalid API key"
    end
  end

  describe "successful authentication" do
    test "assigns api_key and api_user via Authorization header", %{conn: conn} do
      {raw_key, api_key, user} = create_api_key()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> call_plug()

      refute conn.halted
      assert conn.assigns[:api_key].id == api_key.id
      assert conn.assigns[:api_user] == user.id
    end

    test "assigns api_key via x-api-key header", %{conn: conn} do
      {raw_key, api_key, _user} = create_api_key()

      conn =
        conn
        |> put_req_header("x-api-key", raw_key)
        |> call_plug()

      refute conn.halted
      assert conn.assigns[:api_key].id == api_key.id
    end

    test "trims whitespace from key", %{conn: conn} do
      {raw_key, api_key, _user} = create_api_key()

      conn =
        conn
        |> put_req_header("authorization", "Bearer  #{raw_key}  ")
        |> call_plug()

      refute conn.halted
      assert conn.assigns[:api_key].id == api_key.id
    end
  end
end
