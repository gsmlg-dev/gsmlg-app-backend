defmodule GsmlgAppWeb.AppsPrivacyController do
  use GsmlgAppWeb, :app_privacy_controller

  def privacy(conn, %{"app_label" => "geoip_lookup"} = _params) do
    render(conn, :geoip_lookup)
  end

  def privacy(conn, %{"app_label" => "whois_lookup"} = _params) do
    render(conn, :whois_lookup)
  end

  def privacy(conn, %{"app_label" => "simple_mirror"} = _params) do
    render(conn, :simple_mirror)
  end

  def privacy(conn, %{"app_label" => "yellowdog_dns"} = _params) do
    render(conn, :yellowdog_dns)
  end

  def privacy(conn, %{"app_label" => "semaphore_client"} = _params) do
    render(conn, :semaphore_client)
  end
end
