defmodule GsmlgAppWeb.ClipsController do
  use GsmlgAppWeb, :app_controller

  def geo_map(
        conn,
        %{"code" => "EKH9I7409xgnVX9fw0D9QCgZYQ0iOpzOa1SVSazMPdfMnEP7Jx5oJL8DwW8B1sUm"} = params
      ) do
    longitude = params["longitude"] || 0
    latitude = params["latitude"] || 0
    render(conn, :geo_map, layout: false, longitude: longitude, latitude: latitude)
  end
end
