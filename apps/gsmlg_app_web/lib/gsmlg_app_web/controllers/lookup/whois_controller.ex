defmodule GsmlgAppWeb.Lookup.WhoisController do
  use GsmlgAppWeb, :controller
  require Logger

  action_fallback(GsmlgAppWeb.FallbackController)

  def query(conn, %{"query" => query}) do
    case GSMLG.Whois.lookup_raw(query) do
      {:error, unknown} ->
        Logger.error("Unknown Error #{inspect(unknown)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unsupported Query")

      {:ok, whois_list} ->
        conn
        |> render(:list, whois_list: whois_list)
    end
  end

  def query(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, error: "Query parameter is required")
  end

  def query_domain(conn, %{"query" => query} = _params) do
    case GSMLG.Whois.lookup_raw(query) do
      {:error, :nxdomain} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Domain Not Found")

      {:error, :unsupported} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unsupported Domain")

      {:ok, whois} ->
        conn
        |> render(:list, whois_list: whois)

      {:error, unknown} ->
        Logger.error("Unknown Error #{inspect(unknown)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unknown Error")
    end
  end

  def query_domain(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, error: "Query parameter is required")
  end

  def query_ip(conn, %{"query" => query} = _params) do
    case GSMLG.Whois.lookup_raw(query) do
      {:error, :unsupported} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unsupported IP")

      {:ok, whois} ->
        conn
        |> render(:list, whois_list: whois)

      {:error, unknown} ->
        Logger.error("Unknown Error #{inspect(unknown)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unknown Error")
    end
  end

  def query_ip(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, error: "Query parameter is required")
  end

  def query_as(conn, %{"query" => query} = _params) do
    case GSMLG.Whois.lookup_raw(query) do
      {:error, :unsupported} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unsupported AS")

      {:ok, whois} ->
        conn
        |> render(:list, whois_list: whois)

      {:error, unknown} ->
        Logger.error("Unknown Error #{inspect(unknown)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: "Unknown Error")
    end
  end

  def query_as(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:error, error: "Query parameter is required")
  end
end
