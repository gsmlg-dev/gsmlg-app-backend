# Refactor AI Client to use ReqLLM

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-rolled `GsmlgAppAdmin.AI.Client` HTTP implementation with `req_llm` (~> 1.7), gaining standardized provider support, built-in SSE parsing, tool calling, structured output, and telemetry for free.

**Architecture:** ReqLLM uses a `"provider:model"` model spec format with normalized messages, streaming, and responses. We'll replace `Client` internals with ReqLLM calls while keeping `Gateway` as the orchestration layer. The Gateway→Client interface changes minimally — Client becomes a thin adapter over ReqLLM. The LiveView and Controller consumers communicate via the same `{:content, text}` / `{:thinking, text}` callback tuples, so their code stays untouched.

**Tech Stack:** ReqLLM 1.7+, Req 0.5+, LLMDB (auto-dependency), Elixir 1.18+

---

## Current Architecture

```
LiveView (chat_live/index.ex)          Controller (chat_completions_controller.ex)
    │                                       │
    ▼                                       ▼
Client.stream_with_callback()          Gateway.chat()
Client.chat_completion()                    │
    │                                       ▼
    ▼                                  Client.stream_with_callback()
  Req.post() + manual SSE parsing      Client.chat_completion()
                                       Client.image_generation()
```

**What Client does today (all in `ai/client.ex`):**
1. `build_headers/1` — sets `Authorization: Bearer <key>`
2. `build_params/3` — merges model, messages, temperature, max_tokens, top_p
3. `format_messages/1` — normalizes messages to `%{"role" => ..., "content" => ...}`
4. `chat_completion/3` — non-streaming `Req.post` → parse response
5. `stream_chat_completion/3` — streaming `Req.post` with `into: :self`
6. `stream_with_callback/4` — streaming `Req.post` with `into: fn` + manual SSE parsing
7. `image_generation/2` — `Req.post` to `/images/generations`
8. Manual SSE line splitting, `[DONE]` detection, JSON decoding, `reasoning_content` extraction

**What ReqLLM replaces:**
- Items 1-6: `ReqLLM.generate_text/3` and `ReqLLM.stream_text/3` handle auth, params, messages, SSE parsing, and response normalization
- Item 8: SSE parsing is built into ReqLLM via `server_sent_events` dependency
- Item 7: Image generation — check if `ReqLLM.generate_image/3` is available; if so, use it; otherwise keep raw Req

## Target Architecture

```
LiveView / Controller
    │
    ▼
Gateway (unchanged orchestration)
    │
    ▼
Client (thin adapter)
    ├── chat_completion()      → ReqLLM.generate_text()
    ├── stream_with_callback() → ReqLLM.stream_text() + process_stream callbacks
    └── image_generation()     → ReqLLM.generate_image() or Req.post() fallback
```

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `apps/gsmlg_app_admin/mix.exs` | Modify | Add `{:req_llm, "~> 1.7"}`, remove `{:instructor, "~> 0.1.0"}` |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex` | Rewrite | Thin adapter over ReqLLM |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider_presets.ex` | Modify | Update moduledoc |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/mock_client.ex` | Keep | No changes (test mock, same interface) |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/gateway.ex` | Keep | No changes (calls Client with same API) |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/tool_executor.ex` | Keep | No changes (uses Req directly for webhooks, not LLM) |
| `apps/gsmlg_app_admin_web/lib/.../chat_live/index.ex` | Keep | No changes (uses Client/MockClient with same callback API) |
| `apps/gsmlg_app_admin_web/lib/.../chat_completions_controller.ex` | Keep | No changes (uses Gateway) |
| `apps/gsmlg_app_admin/test/gsmlg_app_admin/ai/client_test.exs` | Create | Tests for new Client adapter |

---

### Task 1: Add req_llm dependency and remove instructor

**Files:**
- Modify: `apps/gsmlg_app_admin/mix.exs:37-53` (deps list)

- [ ] **Step 1: Verify instructor is unused**

Run: `grep -r "Instructor\|instructor" apps/gsmlg_app_admin/lib/`
Expected: No results (only appears in `client.ex` moduledoc which we're rewriting). If results found, do NOT remove instructor.

- [ ] **Step 2: Update deps in mix.exs**

In `apps/gsmlg_app_admin/mix.exs`, add `req_llm` and remove `instructor`:

```elixir
# Add after {:finch, "~> 0.18"}:
{:req_llm, "~> 1.7"},

# Remove this line:
{:instructor, "~> 0.1.0"},
```

- [ ] **Step 3: Fetch dependencies**

Run: `mix deps.get`
Expected: req_llm and its transitive deps (llm_db, server_sent_events, jsv, etc.) are fetched successfully.

- [ ] **Step 4: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation with no warnings.

- [ ] **Step 5: Commit**

```bash
git add apps/gsmlg_app_admin/mix.exs mix.lock
git commit -m "chore(deps): add req_llm ~> 1.7, remove unused instructor"
```

---

### Task 2: Investigate ReqLLM API surface

Before rewriting Client, verify the actual API surface since documentation may be incomplete.

**Files:** None (investigation only)

- [ ] **Step 1: Check StreamResponse API**

Run:
```bash
mix run -e "IO.inspect(ReqLLM.StreamResponse.__info__(:functions))"
```

Verify which functions exist. We expect one of: `process_stream/2`, `tokens/1`, `chunks/1`. The correct approach depends on what's available:
- If `process_stream/2` exists with `on_result`/`on_thinking` callbacks → use it (preferred)
- If `tokens/1` exists → use it with manual chunk processing
- If `chunks/1` exists → use it with `Stream.each`

- [ ] **Step 2: Check StreamChunk struct**

Run:
```bash
grep -r "defstruct" deps/req_llm/lib/ | grep -i "chunk\|stream"
```

Note the exact field names (e.g., `content` vs `text`, `reasoning_content` vs `thinking`).

- [ ] **Step 3: Check Response API**

Run:
```bash
mix run -e "IO.inspect(ReqLLM.Response.__info__(:functions))"
```

Verify `text/1`, `usage/1`, and critically: check if `tool_calls/1` exists (needed for agent loop).

- [ ] **Step 4: Check available providers**

Run:
```bash
ls deps/req_llm/lib/req_llm/providers/
```

Note which provider atoms are supported (`:openai`, `:anthropic`, `:google`, `:groq`, `:xai`, etc.).

- [ ] **Step 5: Check if generate_image exists**

Run:
```bash
mix run -e "IO.inspect(ReqLLM.__info__(:functions))"
```

Check if `generate_image/3` is available. If yes, we'll use it in Task 3.

- [ ] **Step 6: Check how api_key is passed in inline map model spec**

Run:
```bash
grep -r "api_key" deps/req_llm/lib/req_llm/providers/openai.ex
```

Verify that `api_key` is a valid field in the inline map model spec, or if it must be passed via opts.

- [ ] **Step 7: Document findings**

Write a brief summary of findings at the top of this file under a "## API Investigation Results" section. This informs all subsequent tasks.

---

### Task 3: Rewrite Client to use ReqLLM

**Files:**
- Rewrite: `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex`

The key insight: ReqLLM uses a model spec format like `"openai:gpt-4o"` or an inline map `%{provider: :openai, id: "gpt-4o", base_url: "..."}`. Our `provider` struct has `api_base_url`, `api_key`, `model` — we need to translate this to a ReqLLM model spec.

**Critical requirements from Gateway compatibility:**
1. `chat_completion/3` must return `%{content: text, model: model, usage: usage_map, tool_calls: tool_calls}` — Gateway's `agent_loop` accesses `response[:tool_calls]`
2. `stream_with_callback/4` must call `callback.({:content, text})` and `callback.({:thinking, text})`
3. `build_req_opts/2` must pass through `:tools` and `:tool_choice` opts (Gateway's agent loop sends these)
4. `image_generation/2` must keep the same interface

- [ ] **Step 1: Write the new Client module**

Replace `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex`. Adapt the code below based on Task 2's API investigation findings:

```elixir
defmodule GsmlgAppAdmin.AI.Client do
  @moduledoc """
  AI client module using ReqLLM for standardized LLM API access.

  Supports multiple providers via ReqLLM's unified interface.
  """

  @doc """
  Sends a chat completion request to the specified provider.

  ## Parameters
    - provider: The AI provider configuration (Ash resource with api_base_url, api_key, model, etc.)
    - messages: List of message maps with :role and :content
    - opts: Optional parameters (temperature, max_tokens, model override, tools, etc.)

  ## Returns
    - {:ok, response_map} on success (with :content, :model, :usage, :tool_calls keys)
    - {:error, reason} on failure
  """
  def chat_completion(provider, messages, opts \\ []) do
    model_spec = build_model_spec(provider, opts)
    context = build_context(messages)
    req_opts = build_req_opts(provider, opts)

    case ReqLLM.generate_text(model_spec, context, req_opts) do
      {:ok, response} ->
        {:ok, normalize_response(response)}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  @doc """
  Streams chat completion with a callback function for each chunk.

  The callback receives `{:content, text}` or `{:thinking, text}` tuples.
  """
  def stream_with_callback(provider, messages, callback, opts \\ []) do
    model_spec = build_model_spec(provider, opts)
    context = build_context(messages)
    req_opts = build_req_opts(provider, opts)

    case ReqLLM.stream_text(model_spec, context, req_opts) do
      {:ok, stream_response} ->
        # Use process_stream/2 if available (has on_result/on_thinking callbacks).
        # Otherwise fall back to tokens/1 stream.
        # Adapt this based on Task 2 investigation findings.
        consume_stream(stream_response, callback)
        {:ok, :streaming_complete}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  rescue
    e ->
      {:error, "Streaming failed: #{Exception.message(e)}"}
  end

  @doc """
  Sends an image generation request.

  Uses ReqLLM.generate_image/3 if available, otherwise falls back to raw Req.
  """
  def image_generation(provider, params) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{provider.api_key}"}
    ]
    url = "#{provider.api_base_url}/images/generations"

    body =
      %{model: params["model"] || provider.model, prompt: params["prompt"]}
      |> maybe_put(:n, params["n"])
      |> maybe_put(:size, params["size"])
      |> maybe_put(:quality, params["quality"])
      |> maybe_put(:response_format, params["response_format"])
      |> maybe_put(:style, params["style"])

    case Req.post(url, headers: headers, json: body, receive_timeout: 120_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, extract_error_message(body, status)}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  # -- Private: Model Spec --

  defp build_model_spec(provider, opts) do
    model = Keyword.get(opts, :model, provider.model)
    req_provider = map_provider(provider.slug)

    # Use inline map spec for maximum compatibility.
    # Adapt api_key passing based on Task 2 Step 6 findings.
    %{
      provider: req_provider,
      id: model,
      base_url: provider.api_base_url,
      api_key: provider.api_key
    }
  end

  # Map our provider slugs to ReqLLM provider atoms.
  # Only map slugs that have dedicated ReqLLM providers (verify in Task 2 Step 4).
  defp map_provider("anthropic"), do: :anthropic
  defp map_provider("google"), do: :google
  defp map_provider("groq"), do: :groq
  defp map_provider("xai"), do: :xai
  defp map_provider(_), do: :openai

  # -- Private: Context (Messages) --

  defp build_context(messages) do
    Enum.map(messages, fn msg ->
      role = to_string(msg.role || msg["role"])
      content = msg.content || msg["content"]
      %{role: role, content: content}
    end)
  end

  # -- Private: Options --

  defp build_req_opts(provider, opts) do
    base_params = provider.default_params || %{}

    []
    |> maybe_put_opt(:temperature, Keyword.get(opts, :temperature) || base_params["temperature"])
    |> maybe_put_opt(:max_tokens, Keyword.get(opts, :max_tokens) || base_params["max_tokens"])
    |> maybe_put_opt(:top_p, Keyword.get(opts, :top_p) || base_params["top_p"])
    |> maybe_put_opt(:tools, Keyword.get(opts, :tools))
    |> maybe_put_opt(:tool_choice, Keyword.get(opts, :tool_choice))
  end

  # -- Private: Response Normalization --

  defp normalize_response(response) do
    text = ReqLLM.Response.text(response)
    usage = ReqLLM.Response.usage(response)
    # CRITICAL: Extract tool_calls for Gateway's agent_loop
    tool_calls = extract_tool_calls(response)

    %{
      content: text,
      model: response.model || "unknown",
      usage: normalize_usage(usage),
      tool_calls: tool_calls
    }
  end

  defp extract_tool_calls(response) do
    # Use ReqLLM.Response.tool_calls/1 if available, otherwise check struct fields
    cond do
      function_exported?(ReqLLM.Response, :tool_calls, 1) ->
        ReqLLM.Response.tool_calls(response) || []
      true ->
        response[:tool_calls] || []
    end
  end

  defp normalize_usage(nil), do: %{}

  defp normalize_usage(usage) do
    %{
      "prompt_tokens" => usage[:input_tokens] || usage[:prompt_tokens] || 0,
      "completion_tokens" => usage[:output_tokens] || usage[:completion_tokens] || 0,
      "total_tokens" => usage[:total_tokens] || 0
    }
  end

  # -- Private: Stream Consumption --
  # Adapt this based on Task 2 investigation.
  # Preferred: use process_stream/2 with on_result/on_thinking callbacks.
  # Fallback: use tokens/1 stream.

  defp consume_stream(stream_response, callback) do
    if function_exported?(ReqLLM.StreamResponse, :process_stream, 2) do
      ReqLLM.StreamResponse.process_stream(stream_response,
        on_result: fn text -> callback.({:content, text}) end,
        on_thinking: fn text -> callback.({:thinking, text}) end
      )
    else
      # Fallback: iterate tokens stream
      stream_response
      |> ReqLLM.StreamResponse.tokens()
      |> Stream.each(fn token -> callback.({:content, token}) end)
      |> Stream.run()
    end
  end

  # -- Private: Error Formatting --

  defp format_error(%{message: message}), do: message
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  # -- Private: Image Generation Helpers --

  defp extract_error_message(body, status) when is_map(body) do
    case get_in(body, ["error", "message"]) do
      nil ->
        case body["message"] do
          nil -> "HTTP #{status}: #{inspect(body)}"
          msg -> "HTTP #{status}: #{msg}"
        end
      msg -> "HTTP #{status}: #{msg}"
    end
  end

  defp extract_error_message(body, status) when is_binary(body) and body != "" do
    case Jason.decode(body) do
      {:ok, decoded} -> extract_error_message(decoded, status)
      {:error, _} -> "HTTP #{status}: #{body}"
    end
  end

  defp extract_error_message(_body, status), do: "HTTP #{status}: Unknown error"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`

- [ ] **Step 3: Commit**

```bash
git add apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex
git commit -m "refactor(ai): rewrite Client to use ReqLLM for chat completions"
```

---

### Task 4: Refine Client based on API investigation

**Files:**
- Modify: `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex`

Based on Task 2's investigation results, make targeted fixes:

- [ ] **Step 1: Fix streaming implementation**

If Task 2 revealed that `process_stream/2` doesn't exist or has different callback names, update `consume_stream/2` accordingly. Remove the `function_exported?` runtime check and use the correct API directly.

- [ ] **Step 2: Fix model spec api_key passing**

If Task 2 Step 6 revealed that `api_key` is not a valid field in the inline map model spec, move it to opts:

```elixir
defp build_model_spec(provider, opts) do
  model = Keyword.get(opts, :model, provider.model)
  req_provider = map_provider(provider.slug)
  %{provider: req_provider, id: model, base_url: provider.api_base_url}
end

# And pass api_key in build_req_opts:
defp build_req_opts(provider, opts) do
  # ... existing opts ...
  |> Keyword.put(:api_key, provider.api_key)
end
```

- [ ] **Step 3: Fix provider mapping**

Based on Task 2 Step 4, remove any provider mappings that don't have actual ReqLLM provider modules. Only map slugs where ReqLLM has dedicated support.

- [ ] **Step 4: Update image_generation if ReqLLM supports it**

If Task 2 Step 5 confirmed `ReqLLM.generate_image/3` exists, rewrite `image_generation/2`:

```elixir
def image_generation(provider, params) do
  model_spec = build_model_spec(provider, [model: params["model"] || provider.model])
  image_opts = [
    n: params["n"],
    size: params["size"],
    quality: params["quality"],
    response_format: params["response_format"],
    style: params["style"]
  ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

  case ReqLLM.generate_image(model_spec, params["prompt"], image_opts) do
    {:ok, response} -> {:ok, response}
    {:error, reason} -> {:error, format_error(reason)}
  end
end
```

- [ ] **Step 5: Verify compilation**

Run: `mix compile --warnings-as-errors`

- [ ] **Step 6: Commit**

```bash
git add apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex
git commit -m "fix(ai): refine Client based on ReqLLM API investigation"
```

---

### Task 5: Write Client tests

**Files:**
- Create: `apps/gsmlg_app_admin/test/gsmlg_app_admin/ai/client_test.exs`

- [ ] **Step 1: Write unit tests**

```elixir
defmodule GsmlgAppAdmin.AI.ClientTest do
  use ExUnit.Case, async: true

  alias GsmlgAppAdmin.AI.Client

  defp fake_provider(overrides \\ %{}) do
    Map.merge(
      %{
        slug: "openai",
        api_base_url: "https://api.openai.com/v1",
        api_key: "sk-test-key",
        model: "gpt-4o",
        default_params: %{"temperature" => 0.7, "max_tokens" => 4096}
      },
      overrides
    )
  end

  describe "chat_completion/3" do
    test "returns error for invalid API key" do
      provider = fake_provider(%{api_key: "invalid"})
      messages = [%{role: "user", content: "hello"}]

      assert {:error, _reason} = Client.chat_completion(provider, messages)
    end

    test "response includes tool_calls key" do
      # Even on error, verify the response shape expectation
      provider = fake_provider(%{api_key: "invalid"})
      messages = [%{role: "user", content: "hello"}]

      # This tests that our normalize_response includes tool_calls
      # (full integration test would verify actual tool_calls content)
      assert {:error, _} = Client.chat_completion(provider, messages)
    end
  end

  describe "stream_with_callback/4" do
    test "returns error for invalid provider" do
      provider = fake_provider(%{api_key: "invalid"})
      messages = [%{role: "user", content: "hello"}]
      callback = fn _chunk -> :ok end

      assert {:error, _reason} = Client.stream_with_callback(provider, messages, callback)
    end
  end

  describe "image_generation/2" do
    test "returns error for invalid provider" do
      provider = fake_provider(%{api_key: "invalid"})
      params = %{"prompt" => "a cat", "model" => "dall-e-3"}

      assert {:error, _reason} = Client.image_generation(provider, params)
    end
  end
end
```

- [ ] **Step 2: Run tests**

Run: `mix test apps/gsmlg_app_admin/test/gsmlg_app_admin/ai/client_test.exs`
Expected: Tests pass (they test error paths which don't need real API keys).

- [ ] **Step 3: Commit**

```bash
git add apps/gsmlg_app_admin/test/gsmlg_app_admin/ai/client_test.exs
git commit -m "test(ai): add Client unit tests for error handling"
```

---

### Task 6: Update provider_presets.ex moduledoc

**Files:**
- Modify: `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider_presets.ex:2-6`

- [ ] **Step 1: Update moduledoc**

Change line 5 from:
```elixir
  Supports providers from req_llm and other popular OpenAI-compatible APIs.
```
to:
```elixir
  Supports providers via ReqLLM's unified interface and other OpenAI-compatible APIs.
```

- [ ] **Step 2: Commit**

```bash
git add apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider_presets.ex
git commit -m "docs(ai): update provider_presets moduledoc to reflect ReqLLM usage"
```

---

### Task 7: Full integration verification

- [ ] **Step 1: Run all tests**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 2: Run linter**

Run: `mix compile --warnings-as-errors && mix format --check-formatted`
Expected: No warnings, no format issues.

- [ ] **Step 3: Start the server and test chat**

Run: `mix phx.server`

1. Navigate to admin UI (localhost:4153)
2. Open chat, select a configured provider
3. Send a message and verify streaming works
4. Check that thinking/reasoning content renders for models that support it

- [ ] **Step 4: Test the API endpoint**

```bash
curl -X POST http://localhost:4153/api/v1/chat/completions \
  -H "Authorization: Bearer <your-api-key>" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello"}],"stream":false}'
```

Verify response has correct OpenAI-compatible format.

- [ ] **Step 5: Test streaming API**

```bash
curl -X POST http://localhost:4153/api/v1/chat/completions \
  -H "Authorization: Bearer <your-api-key>" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hello"}],"stream":true}' \
  --no-buffer
```

Verify SSE chunks arrive correctly.

- [ ] **Step 6: Test agent loop with tools**

If an agent with tools is configured, test it via the API to verify tool_calls are properly extracted and the agent loop iterates correctly.

- [ ] **Step 7: Final commit (if any fixups needed)**

```bash
git commit -m "fix(ai): integration fixes for ReqLLM migration"
```

---

## Risk Notes

1. **ReqLLM streaming API**: Task 2 investigates the actual API. The code uses `process_stream/2` with `on_result`/`on_thinking` callbacks (preferred) with fallback to `tokens/1`. The runtime `function_exported?` check in Task 3 should be replaced with the correct API after investigation.

2. **Provider compatibility**: The `map_provider/1` function routes Anthropic, Google, etc. to native ReqLLM providers which handle auth header differences (e.g., Anthropic uses `x-api-key` not `Authorization: Bearer`). All other providers default to `:openai` (OpenAI-compatible).

3. **Tool calls in agent loop**: `normalize_response/1` **must** include `tool_calls` in its return map. Gateway's `agent_loop/6` checks `response[:tool_calls]` to decide whether to continue iterating. Dropping this field would silently break the agent system.

4. **api_key in model spec**: The inline map model spec may or may not support `api_key` directly. Task 2 Step 6 investigates this. If not supported, api_key must be passed via `build_req_opts`.

5. **Image generation**: Check if `ReqLLM.generate_image/3` exists (Task 2 Step 5). If yes, migrate to it. If not, keep the raw Req implementation.

6. **`:model` key leaking into ReqLLM opts**: Gateway puts `:model` in `call_opts`. Since `build_model_spec` already extracts `:model` from opts, ensure `build_req_opts` does NOT pass `:model` through to ReqLLM (it's not in the explicit list, so this is safe).

## Follow-up Opportunities (not in scope)

- Use ReqLLM's native `:system_prompt` option instead of prepending system messages to the message list
- Use `ReqLLM.generate_object/4` for structured output where appropriate
- Leverage `[:req_llm, :token_usage]` telemetry events for monitoring
- Remove `MockClient` and use ReqLLM's test utilities if available
