defmodule GsmlgAppAdminWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Authenticates API gateway requests via `Authorization: Bearer gsk_...` or
  `x-api-key: gsk_...` header. Looks up the key by prefix, verifies the hash,
  checks active/expiry, and assigns `api_key` + `api_user` to conn.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, raw_key} <- extract_key(conn),
         {:ok, api_key} <- lookup_key(raw_key),
         :ok <- verify_key(raw_key, api_key),
         :ok <- check_active(api_key),
         :ok <- check_expiry(api_key) do
      conn
      |> assign(:api_key, api_key)
      |> assign(:api_user, api_key.user_id)
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{error: %{message: reason, type: "authentication_error"}})
        )
        |> halt()
    end
  end

  defp extract_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        {:ok, String.trim(token)}

      _ ->
        case get_req_header(conn, "x-api-key") do
          [token] -> {:ok, String.trim(token)}
          _ -> {:error, "Missing API key. Provide via Authorization: Bearer or x-api-key header."}
        end
    end
  end

  defp lookup_key(raw_key) when byte_size(raw_key) < 8 do
    {:error, "Invalid API key format."}
  end

  defp lookup_key(raw_key) do
    prefix = String.slice(raw_key, 0, 8)

    require Ash.Query

    case GsmlgAppAdmin.AI.ApiKey
         |> Ash.Query.filter(key_prefix == ^prefix)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, "Invalid API key."}
      {:ok, api_key} -> {:ok, api_key}
      {:error, _} -> {:error, "Invalid API key."}
    end
  end

  defp verify_key(raw_key, api_key) do
    if GsmlgAppAdmin.AI.ApiKey.verify_key(raw_key, api_key.key_hash) do
      :ok
    else
      {:error, "Invalid API key."}
    end
  end

  defp check_active(api_key) do
    if api_key.is_active do
      :ok
    else
      {:error, "API key has been revoked."}
    end
  end

  defp check_expiry(api_key) do
    case api_key.expires_at do
      nil ->
        :ok

      expires_at ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          :ok
        else
          {:error, "API key has expired."}
        end
    end
  end

  @doc """
  Checks if the given api_key has the required scope.
  """
  def has_scope?(api_key, scope) do
    scope in (api_key.scopes || [])
  end
end
