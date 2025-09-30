defmodule GsmlgAppWeb.Lookup.WhoisJSON do
  alias GsmlgApp.Lookup.Whois

  @doc """
  Renders whois info.
  """
  def index(%{whois: whois}) do
    %{data: whois}
  end

  @doc """
  Renders whois info.
  """
  def list(%{whois_list: whois_list}) do
    list =
      Enum.map(whois_list, fn
        {server, data} ->
          %{data: data, server: server}

        item when is_tuple(item) and tuple_size(item) == 2 ->
          {server, data} = item
          %{data: data, server: server}

        item ->
          %{data: inspect(item), server: "unknown"}
      end)

    %{data: list}
  end

  @doc """
  Renders whois error.
  """
  def error(%{error: error}) do
    %{error: true, data: error}
  end
end
