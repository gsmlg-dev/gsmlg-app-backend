defmodule GsmlgAppAdminWeb.Api.V1.RequestHelpers do
  @moduledoc """
  Shared helpers for API v1 controllers.
  """

  @doc """
  Converts a role string to an existing atom.

  Accepts "user", "assistant", "tool", and "function".
  Any other value (including nil, empty string, or potential atom injection attacks)
  defaults to :user.

  ## Examples

      iex> safe_role("user")
      :user

      iex> safe_role("assistant")
      :assistant

      iex> safe_role("__struct__")
      :user

      iex> safe_role(nil)
      :user

      iex> safe_role("")
      :user
  """
  def safe_role(role) when role in ~w(user assistant tool function),
    do: String.to_existing_atom(role)

  def safe_role(_), do: :user

  @doc """
  Extracts the client IP address from a connection, handling both IPv4 and IPv6.
  """
  def client_ip(%Plug.Conn{remote_ip: ip}) do
    :inet.ntoa(ip) |> to_string()
  end

  @doc """
  Detects whether a request targets an Anthropic-format endpoint based on the path.
  Returns `:anthropic` for `/api/v1/messages`, `:openai` otherwise.
  """
  def api_format(%Plug.Conn{request_path: path}) do
    if String.contains?(path, "/messages") do
      :anthropic
    else
      :openai
    end
  end

  @doc """
  Builds a format-aware JSON error body.

  Anthropic format wraps errors in `%{type: "error", error: %{type: ..., message: ...}}`.
  OpenAI format uses `%{error: %{message: ..., type: ...}}`.
  """
  def error_body(:anthropic, type, message) do
    %{type: "error", error: %{type: type, message: message}}
  end

  def error_body(:openai, type, message) do
    %{error: %{message: message, type: type}}
  end

  @doc """
  Generates a URL-safe random ID for API response objects.
  """
  def generate_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  @doc """
  Clamps a float parameter to a range, returning nil for invalid values.
  """
  def clamp_float(nil, _min, _max), do: nil
  def clamp_float(val, min, max) when is_number(val), do: val |> max(min) |> min(max)
  def clamp_float(_val, _min, _max), do: nil

  @doc """
  Clamps an integer parameter to a range, returning nil for invalid values.
  """
  def clamp_int(nil, _min, _max), do: nil
  def clamp_int(val, min, max) when is_integer(val), do: val |> max(min) |> min(max)
  def clamp_int(_val, _min, _max), do: nil

  @max_model_length 256

  @doc """
  Validates a model string for length and format.

  Returns `{:ok, model}` if valid, `{:error, message}` if not.
  """
  def validate_model(nil), do: {:error, "model is required."}
  def validate_model(""), do: {:error, "model is required."}

  def validate_model(model) when is_binary(model) do
    if byte_size(model) > @max_model_length do
      {:error, "model must be #{@max_model_length} characters or fewer."}
    else
      {:ok, model}
    end
  end

  def validate_model(_), do: {:error, "model must be a string."}

  @max_tools 128

  @doc """
  Validates and caps a tools list to prevent oversized payloads.

  Returns the tools list truncated to `@max_tools` items, or nil if not a list.
  """
  def validate_tools(tools) when is_list(tools) and tools != [] do
    Enum.take(tools, @max_tools)
  end

  def validate_tools(_), do: nil

  @doc """
  Validates an image URL for OCR, blocking private/internal addresses.

  Returns `:ok` or `{:error, message}`.
  """
  def validate_image_url(nil), do: :ok
  def validate_image_url(""), do: :ok

  def validate_image_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme not in ["http", "https"] ->
        {:error, "Image URL must use http or https scheme."}

      %URI{host: host} when is_binary(host) ->
        if private_host?(host) do
          {:error, "Image URL must not point to private or internal addresses."}
        else
          :ok
        end

      _ ->
        {:error, "Invalid image URL."}
    end
  end

  def validate_image_url(_), do: {:error, "Image URL must be a string."}

  @doc """
  Validates and caps the `n` parameter for image generation.
  """
  def validate_image_count(nil), do: nil
  def validate_image_count(n) when is_integer(n), do: min(max(n, 1), 4)
  def validate_image_count(_), do: nil

  # Checks if a hostname resolves to a private/internal IP range.
  defp private_host?(host) do
    host = to_charlist(host)

    case :inet.getaddr(host, :inet) do
      {:ok, ip} -> private_ip?(ip)
      {:error, _} -> false
    end
  end

  defp private_ip?({127, _, _, _}), do: true
  defp private_ip?({10, _, _, _}), do: true
  defp private_ip?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  defp private_ip?({192, 168, _, _}), do: true
  defp private_ip?({169, 254, _, _}), do: true
  defp private_ip?({0, 0, 0, 0}), do: true
  defp private_ip?(_), do: false
end
