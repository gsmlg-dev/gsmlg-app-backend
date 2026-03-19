# PRD: AI Provider Settings & API Gateway Module

## Context

The GSMLG platform has a functional internal AI chat interface with 15+ provider presets, streaming support, and per-conversation settings — but all capability is locked behind the admin web UI. There is no way to expose AI capabilities as an API to external consumers, inject administrative controls (system prompts, memories) transparently, or control/meter external usage. This module turns the existing AI infrastructure into a managed API gateway that exposes both OpenAI-compatible and Anthropic-compatible endpoints for chat, image generation, OCR, and agentic tool use, allowing consumers to use whichever SDK they prefer.

---

## 1. Goals

1. **Dual-compatible chat API** — OpenAI-compatible at `/api/v1/chat/completions` and Anthropic-compatible at `/api/v1/messages`, consumable by standard SDKs
2. **Image generation API** — OpenAI-compatible at `/api/v1/images/generations`, proxying to DALL-E, Stable Diffusion, and other image providers
3. **OCR API** — Extract text from images via `/api/v1/ocr`, leveraging vision-capable LLMs or dedicated OCR providers
4. **Agents & Tools** — Admin-defined agents with tool registries, server-side tool execution loop, and managed tool definitions reusable across agents
5. **User-facing API key management** — create, revoke, scope keys per user
6. **System prompt templates** — admin-configured prompts injected transparently into every chat request
7. **Persistent memory system** — facts/context stored per-user or globally, injected automatically into chat
8. **Usage tracking & rate limiting** — per-key logging, counters, RPM/RPD limits
9. **Admin UI** — manage keys, templates, memories, agents, tools, view usage dashboard

## 2. Non-Goals

- Billing/payment integration
- WebSocket/gRPC transport
- Provider API key rotation / vault integration
- Image editing / inpainting (v1)
- Training / fine-tuning APIs
- Autonomous long-running agent processes (v1 agents are request-scoped)

---

## 3. Core Concepts

### 3.1 API Key Management

External consumers authenticate with keys formatted as `gsk_` + 48 random base64 chars. Only the hash is stored; the full key is shown once at creation. Each key has:

- `key_prefix` (first 8 chars, cleartext for lookup)
- `key_hash` (SHA-256)
- `scopes` — `[:chat_completions, :messages, :images, :ocr, :agents, :models_list]`
- `is_active`, `expires_at` — soft revocation + expiry
- `rate_limit_rpm`, `rate_limit_rpd` — per-key overrides (nil = system default)
- `allowed_providers`, `allowed_models` — restrict access to specific providers/models
- `total_requests`, `total_tokens`, `last_used_at` — aggregate counters

### 3.2 System Prompt Templates

Admin-defined reusable prompt blocks with variable interpolation (`{{memory}}`, `{{user.display_name}}`, `{{date}}`):

- `is_default` — auto-injected into all gateway requests
- `priority` — ordering when multiple templates apply
- API keys can have key-specific template overrides via join table

Assembly: default templates (by priority) → key-specific templates → render variables → prepend as system message(s) before caller's messages.

### 3.3 Memory System

Persistent facts stored with scope:

- **`:global`** — injected for all users
- **`:user`** — injected for a specific user
- **`:api_key`** — injected only for requests using a specific key

Categories: `:fact`, `:instruction`, `:preference`, `:context`. Collected at request time and injected via `{{memory}}` variable in templates, or as a dedicated system message if no template uses the variable.

### 3.4 Image Generation

The gateway proxies image generation requests to upstream providers via an OpenAI-compatible `/api/v1/images/generations` endpoint. Admin configures image providers similarly to chat providers, with dedicated provider entries for image-capable services.

**Supported upstream providers**:

| Provider | API Style | Models |
|---|---|---|
| OpenAI DALL-E | OpenAI Images API | `dall-e-3`, `dall-e-2`, `gpt-image-1` |
| Stability AI | REST API | `stable-diffusion-xl`, `stable-diffusion-3`, `stable-image-ultra` |
| Zhipu CogView | OpenAI-compatible | `cogview-3`, `cogview-4` |
| Together AI | OpenAI-compatible | `stabilityai/stable-diffusion-xl`, `black-forest-labs/FLUX.1` |
| Replicate | REST API | Various diffusion models |
| Self-hosted (ComfyUI/A1111) | REST API | Custom models |

**Admin controls**:

- Per-provider default parameters (size, quality, style)
- Allowed sizes per key (e.g., restrict to `1024x1024` only)
- Max images per request (default: 4)
- Content filtering / safety settings passthrough

**Image storage**: Generated images are returned as URLs (upstream provider URLs) or base64, depending on caller's `response_format` parameter. The gateway does NOT store generated images — it proxies the upstream response. Optional future enhancement: cache to local storage / S3.

### 3.5 OCR (Optical Character Recognition)

The gateway provides an OCR endpoint at `/api/v1/ocr` that extracts text from images. This is implemented by leveraging vision-capable LLMs with a standardized OCR prompt, or by routing to dedicated OCR providers.

**Two implementation strategies** (admin-configurable per provider):

1. **Vision LLM-based OCR** — Sends the image to a vision-capable model (GPT-4o, Claude, Gemini) with a structured OCR system prompt. Supports complex layouts, handwriting, multi-language text. Higher cost, richer output (can preserve structure, tables, formatting).

2. **Dedicated OCR provider** — Routes to specialized OCR services for high-volume, low-cost extraction. Faster, cheaper, but less capable with complex layouts.

**Supported upstream providers**:

| Provider | Type | Capabilities |
|---|---|---|
| OpenAI GPT-4o / GPT-4o-mini | Vision LLM | General OCR, handwriting, structured extraction |
| Anthropic Claude (Sonnet/Opus) | Vision LLM | General OCR, document understanding |
| Google Gemini | Vision LLM | General OCR, multi-language |
| Google Cloud Vision | Dedicated OCR | Text detection, document parsing |
| Tesseract (self-hosted) | Dedicated OCR | Open-source, on-premise |
| PaddleOCR (self-hosted) | Dedicated OCR | Multi-language, high accuracy |

**Admin controls**:

- Default OCR provider/model selection
- System prompt template for vision LLM OCR (customizable extraction instructions)
- Output format preference: `text` (plain), `markdown` (structured), `json` (key-value pairs)
- Max image size limit
- Language hints

### 3.6 Agents & Tools

The gateway supports creating **agents** (preconfigured AI assistants) with **tools** (functions the LLM can invoke). This enables server-side agentic workflows where the LLM can call tools, receive results, and continue reasoning — all within a single API request.

#### 3.6.1 Tool Definitions

A **Tool** is a reusable function definition that the LLM can invoke. Tools are managed by admins and stored in the database. Each tool has:

- **Schema** — JSON Schema defining the tool's name, description, and parameters (OpenAI function calling format)
- **Execution type** — how the tool runs when invoked:
  - **`:webhook`** — calls an external HTTP endpoint with the tool arguments as JSON body
  - **`:builtin`** — executes a predefined Elixir function (e.g., database lookup, internal API call)
  - **`:code`** — runs admin-defined Elixir code in a sandboxed environment (via `Code.eval_string` with restricted imports)
  - **`:mcp`** — invokes a tool on a connected MCP (Model Context Protocol) server (see section 3.6.4)
  - **`:passthrough`** — does NOT execute server-side; returns tool call to the API consumer for client-side execution (standard function calling behavior)
- **Authentication** — webhook tools can include auth headers (Bearer token, API key) stored securely
- **Timeout** — per-tool execution timeout (default: 30s)
- **Rate limit** — optional per-tool invocation limit

**Example tool definitions**:

```json
{
  "name": "get_weather",
  "description": "Get current weather for a location",
  "execution_type": "webhook",
  "webhook_url": "https://api.weather.example.com/current",
  "webhook_headers": {"Authorization": "Bearer {{secret:weather_api_key}}"},
  "parameters": {
    "type": "object",
    "properties": {
      "location": {"type": "string", "description": "City name or coordinates"},
      "units": {"type": "string", "enum": ["celsius", "fahrenheit"]}
    },
    "required": ["location"]
  }
}
```

```json
{
  "name": "search_knowledge_base",
  "description": "Search the internal knowledge base for relevant documents",
  "execution_type": "builtin",
  "builtin_handler": "knowledge_base_search",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {"type": "string"},
      "limit": {"type": "integer", "default": 5}
    },
    "required": ["query"]
  }
}
```

#### 3.6.2 Agents

An **Agent** is an admin-configured AI persona that combines a model, system prompt, tools, and behavioral settings into a reusable unit. Instead of API consumers needing to assemble tools + system prompts + model parameters on every request, they invoke a named agent.

Each agent has:

- **Name & slug** — human-readable name and unique identifier for API reference
- **Model** — default model (overridable per request)
- **Provider** — preferred provider (optional; falls back to automatic resolution)
- **System prompt template** — links to one or more `SystemPromptTemplate` resources
- **Tools** — ordered list of tools available to this agent (via join table)
- **Max iterations** — maximum tool call → result → LLM cycles before forcing a final response (default: 10, max: 25)
- **Tool choice** — default tool selection strategy: `"auto"`, `"required"`, `"none"`, or a specific tool name
- **Memories** — agent-scoped memories (injected only when this agent runs)
- **Model params** — default temperature, max_tokens, top_p for this agent
- **Is active** — soft enable/disable

**Agent execution model**: When a request targets an agent, the gateway runs a **tool execution loop**:

```
1. Build request (system prompt + memories + tools + user messages)
2. Call LLM
3. If response contains tool_calls:
   a. For each tool_call:
      - If execution_type is :passthrough → collect for client return
      - Otherwise → execute tool server-side → collect result
   b. If any :passthrough tools were called → return to client with tool_calls
      (client executes, sends back tool results, loop continues)
   c. If all tools executed server-side → append tool results to messages → goto 2
4. If response is final text (no tool_calls) → return response
5. If max_iterations exceeded → return last response + warning
```

This supports three usage patterns:

1. **Fully server-side agents** — all tools are `:webhook`/`:builtin`/`:code`/`:mcp`. The client sends a message, the server handles the entire tool loop, and returns the final answer. The client sees a single request/response (or stream).

2. **Fully client-side tools (passthrough)** — all tools are `:passthrough`. The gateway adds tool definitions to the LLM request, but tool calls are returned to the client for execution. This is standard OpenAI/Anthropic function calling behavior, enhanced with admin-managed tool definitions.

3. **Hybrid** — some tools execute server-side, others are `:passthrough`. The server handles what it can and returns remaining tool calls to the client.

#### 3.6.3 Tool Use in Chat API (Non-Agent)

Even without using named agents, the chat endpoints (`/api/v1/chat/completions` and `/api/v1/messages`) support tool use passthrough. API consumers can include `tools`/`functions` in their request, and the gateway passes them through to the upstream provider. Admin-managed tools can also be injected per API key (similar to how system prompts are injected).

**OpenAI format** — `tools` array with `type: "function"` entries, response with `tool_calls` in `choices[0].message`

**Anthropic format** — `tools` array with `name`/`description`/`input_schema`, response with `tool_use` content blocks

The Gateway normalizes between these formats using the same pattern as chat message normalization.

#### 3.6.4 MCP (Model Context Protocol) Integration

Tools can be sourced from external **MCP servers** — standardized tool providers that expose tools, resources, and prompts over a JSON-RPC protocol. Instead of manually defining each tool's schema and execution logic, admins connect an MCP server and all its tools become available automatically.

**MCP Server Connections**

An `McpServer` resource represents a connected MCP server. Each entry has:

- **Name & slug** — human-readable identifier
- **Transport type** — how to connect to the MCP server:
  - **`:stdio`** — launch a local process and communicate over stdin/stdout (e.g., `npx @modelcontextprotocol/server-filesystem /path`)
  - **`:sse`** — connect to a remote HTTP SSE endpoint (e.g., `https://mcp.example.com/sse`)
  - **`:streamable_http`** — connect via the newer Streamable HTTP transport (e.g., `https://mcp.example.com/mcp`)
- **Connection config** — transport-specific settings:
  - `:stdio` — `command`, `args`, `env` (environment variables), `cwd`
  - `:sse` — `url`, `headers` (auth headers)
  - `:streamable_http` — `url`, `headers`
- **Auto-discover tools** — on connect, the gateway calls `tools/list` to enumerate available tools
- **Is active** — soft enable/disable the entire server
- **Health status** — last ping result, connection state

**How MCP tools work**:

1. Admin adds an MCP server connection in the admin UI (URL or stdio command)
2. Gateway connects and calls `tools/list` → receives tool schemas (name, description, inputSchema)
3. Each MCP tool is automatically registered as an `AI.Tool` with `execution_type: :mcp` and a reference to the `McpServer`
4. When the LLM calls an MCP tool during agent execution, the gateway invokes `tools/call` on the MCP server with the tool name and arguments
5. The MCP server executes the tool and returns the result
6. Tool schemas are refreshed periodically or on-demand via `tools/list`

**MCP tool auto-sync**: When an MCP server's tools change (tools added/removed/updated), the gateway detects this via periodic `tools/list` polling or MCP notifications. Auto-synced tools are linked to their MCP server — deleting or disabling the server disables all its tools.

**Admin can override MCP tool properties**: After auto-discovery, admins can customize individual MCP tools:
- Override description (for better LLM understanding)
- Set per-tool rate limits
- Disable specific tools from a server (without disabling the whole server)
- Assign to specific agents

**MCP resources and prompts**: Beyond tools, MCP servers can also expose:
- **Resources** — contextual data (files, database records, API docs) that can be injected into system prompts via `{{mcp_resource:server/resource_uri}}` template variables
- **Prompts** — preconfigured prompt templates from the MCP server, available as system prompt template sources

**Example MCP server configurations**:

```json
{
  "name": "Filesystem Tools",
  "slug": "filesystem",
  "transport_type": "stdio",
  "connection_config": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/data/shared"],
    "env": {}
  }
}
```

```json
{
  "name": "GitHub Tools",
  "slug": "github",
  "transport_type": "stdio",
  "connection_config": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {"GITHUB_PERSONAL_ACCESS_TOKEN": "{{secret:github_pat}}"}
  }
}
```

```json
{
  "name": "Company Knowledge Base",
  "slug": "knowledge-base",
  "transport_type": "streamable_http",
  "connection_config": {
    "url": "https://kb-mcp.internal.example.com/mcp",
    "headers": {"Authorization": "Bearer {{secret:kb_token}}"}
  }
}
```

**Connection lifecycle** (managed by `McpConnectionManager` GenServer):

```
1. Admin adds MCP server → McpConnectionManager.connect(server)
2. Establish transport (spawn stdio process or open HTTP connection)
3. Send initialize request → receive server capabilities
4. Call tools/list → auto-create AI.Tool records (execution_type: :mcp)
5. Optionally call resources/list → make available for template variables
6. Keep connection alive (heartbeat for stdio, reconnect for HTTP)
7. On tool_call → route to correct MCP server via tools/call
8. On server disconnect → mark tools as unavailable, attempt reconnect
```

### 3.7 Rate Limiting

ETS-based sliding window counters (consistent with project's existing ETS usage for sessions). Per-key RPM/RPD. Returns HTTP 429 with `Retry-After` header and OpenAI-compatible error body. System defaults: 60 RPM, 1000 RPD.

### 3.7 Usage Tracking

Every request logged to `ApiUsageLog` with: api_key, provider, model, token counts (or image count for image generation), duration, status, IP. Aggregate counters on `ApiKey` updated after each request (mirrors existing `Provider.increment_usage` pattern). The `endpoint_type` field distinguishes between `:chat`, `:image`, and `:ocr` requests.

---

## 4. Ash Resources

All new resources registered in the existing `GsmlgAppAdmin.AI` domain.

### 4.1 `AI.ApiKey` — table `ai_api_keys`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name | string | max 100, required |
| description | string | nullable |
| key_prefix | string(8) | unique, for lookup |
| key_hash | string | sensitive, SHA-256 |
| scopes | {:array, :atom} | default `[:chat_completions, :messages, :images, :ocr, :agents]` |
| is_active | boolean | default true |
| expires_at | utc_datetime_usec | nullable |
| last_used_at | utc_datetime_usec | nullable |
| rate_limit_rpm | integer | nullable |
| rate_limit_rpd | integer | nullable |
| allowed_providers | {:array, :uuid} | default [] |
| allowed_models | {:array, :string} | default [] |
| total_requests | integer | default 0 |
| total_tokens | integer | default 0 |

**Relationships**: `belongs_to :user`, `has_many :usage_logs`, `many_to_many :system_prompt_templates`

**Actions**: `:create` (generates key, returns raw once), `:update`, `:revoke`, `:increment_usage`, `:by_prefix`, `:active_for_user`

### 4.2 `AI.SystemPromptTemplate` — table `ai_system_prompt_templates`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name | string | max 100, required |
| slug | string | max 50, unique |
| content | text | required, supports `{{variable}}` |
| is_default | boolean | default false |
| is_active | boolean | default true |
| priority | integer | default 0 |

**Actions**: `:create`, `:update`, `:read`, `:destroy`, `:active_defaults`

### 4.3 `AI.Memory` — table `ai_memories`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| content | text | required |
| category | atom | `:fact`, `:instruction`, `:preference`, `:context` |
| scope | atom | `:global`, `:user`, `:api_key`, `:agent` |
| is_active | boolean | default true |
| priority | integer | default 0 |

**Relationships**: `belongs_to :user` (nullable), `belongs_to :api_key` (nullable), `belongs_to :agent, AI.Agent` (nullable)

**Validations**: user_id required when scope=`:user`, api_key_id required when scope=`:api_key`, agent_id required when scope=`:agent`

**Actions**: `:create`, `:update`, `:read`, `:destroy`, `:for_request` (fetches global + user + key + agent memories)

### 4.4 `AI.ApiUsageLog` — table `ai_api_usage_logs`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| endpoint_type | atom | `:chat`, `:image`, `:ocr`, `:agent` |
| model | string | required |
| prompt_tokens | integer | default 0 |
| completion_tokens | integer | default 0 |
| total_tokens | integer | default 0 |
| images_generated | integer | default 0 (for image generation requests) |
| duration_ms | integer | nullable |
| status | atom | `:success`, `:error`, `:rate_limited` |
| error_message | string | nullable |
| request_ip | string | nullable |

**Relationships**: `belongs_to :api_key`, `belongs_to :provider` (nullable), `belongs_to :agent, AI.Agent` (nullable)

**Indexes**: `(api_key_id, created_at)`, `(created_at)`, `(agent_id, created_at)`

### 4.5 `AI.McpServer` — table `ai_mcp_servers`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name | string | max 100, required |
| slug | string | max 50, unique |
| description | text | nullable |
| transport_type | atom | `:stdio`, `:sse`, `:streamable_http` |
| connection_config | map | transport-specific: command/args/env or url/headers. Sensitive. |
| is_active | boolean | default true |
| auto_sync_tools | boolean | default true |
| health_status | atom | `:connected`, `:disconnected`, `:error`. Default: `:disconnected` |
| last_connected_at | utc_datetime_usec | nullable |
| last_error | string | nullable, last connection/execution error |
| server_info | map | nullable, populated from MCP `initialize` response (name, version, capabilities) |

**Actions**: `:create`, `:update`, `:read`, `:destroy`, `:active`, `:by_slug`, `:update_health`

**Relationships**: `has_many :tools, AI.Tool` (where execution_type = `:mcp`)

### 4.6 `AI.Tool` — table `ai_tools`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name | string | max 100, required, unique within active tools |
| slug | string | max 50, unique |
| description | text | required (used in LLM tool description) |
| execution_type | atom | `:webhook`, `:builtin`, `:code`, `:mcp`, `:passthrough` |
| parameters_schema | map | JSON Schema for tool parameters |
| webhook_url | string | nullable, required when execution_type = `:webhook` |
| webhook_method | atom | `:post`, `:get`, `:put`, `:delete`. Default: `:post` |
| webhook_headers | map | nullable, sensitive. Supports `{{secret:key}}` interpolation |
| builtin_handler | string | nullable, required when execution_type = `:builtin` (Elixir module/function) |
| code_body | text | nullable, required when execution_type = `:code` (Elixir code string) |
| mcp_server_id | uuid FK | nullable, required when execution_type = `:mcp` |
| mcp_tool_name | string | nullable, the tool name as registered on the MCP server |
| is_mcp_synced | boolean | default false. True if auto-created from MCP `tools/list` |
| timeout_ms | integer | default 30_000 (30s) |
| rate_limit_per_minute | integer | nullable, per-tool invocation limit |
| is_active | boolean | default true |
| metadata | map | nullable, arbitrary config (retry policy, response transform, etc.) |

**Actions**: `:create`, `:update`, `:read`, `:destroy`, `:active`, `:by_slug`

**Relationships**: `belongs_to :mcp_server, AI.McpServer` (nullable)

**Validations**:
- `webhook_url` required when `execution_type = :webhook`
- `builtin_handler` required when `execution_type = :builtin`
- `code_body` required when `execution_type = :code`
- `mcp_server_id` + `mcp_tool_name` required when `execution_type = :mcp`
- `parameters_schema` must be valid JSON Schema

### 4.6 `AI.Agent` — table `ai_agents`

| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name | string | max 100, required |
| slug | string | max 50, unique |
| description | text | nullable |
| model | string | nullable (default model, overridable per request) |
| max_iterations | integer | default 10, max 25 |
| tool_choice | string | default `"auto"`. One of: `"auto"`, `"required"`, `"none"`, or tool name |
| model_params | map | default `%{}`. temperature, max_tokens, top_p |
| is_active | boolean | default true |

**Relationships**:
- `belongs_to :provider, AI.Provider` (nullable — falls back to auto-resolution)
- `many_to_many :tools, AI.Tool` (through `ai_agent_tools` join table, with `position` for ordering)
- `many_to_many :system_prompt_templates, AI.SystemPromptTemplate` (through `ai_agent_templates` join table)
- `has_many :memories, AI.Memory` (where scope = `:agent`)

**Actions**: `:create`, `:update`, `:read`, `:destroy`, `:active`, `:by_slug`, `:with_tools_and_templates`

### 4.7 `AI.AgentTool` — join table `ai_agent_tools`

| Field | Type | Notes |
|---|---|---|
| agent_id | uuid FK | |
| tool_id | uuid FK | |
| position | integer | ordering of tools for this agent |
| tool_choice_override | string | nullable, per-agent override for this tool |

Composite PK: `agent_id` + `tool_id`

### 4.8 `AI.AgentTemplate` — join table `ai_agent_templates`

Composite PK: `agent_id` + `system_prompt_template_id`

### 4.9 `AI.ApiKeyTemplate` — join table `ai_api_key_templates`

Composite PK: `api_key_id` + `system_prompt_template_id`

---

## 5. API Endpoints

### Router Changes

New pipeline `api_gateway` with plugs: `ApiKeyAuth`, `RateLimit`, `CORS`.

```elixir
scope "/api/v1", GsmlgAppAdminWeb.Api.V1 do
  pipe_through :api_gateway

  # OpenAI-compatible endpoints
  post "/chat/completions", ChatCompletionsController, :create
  get  "/models",           ModelsController, :index

  # Anthropic-compatible endpoints
  post "/messages",         MessagesController, :create

  # Image generation
  post "/images/generations", ImagesController, :create

  # OCR
  post "/ocr",              OcrController, :create

  # Agent endpoints
  post "/agents/:agent_slug/chat",  AgentController, :chat
  get  "/agents",                   AgentController, :index
  get  "/agents/:agent_slug",       AgentController, :show
  get  "/agents/:agent_slug/tools", AgentController, :tools
end
```

The gateway exposes multiple API surfaces. All share the same authentication (API keys), rate limiting, system prompt injection, and memory system. The Gateway service normalizes requests from any format into a unified internal representation before calling upstream providers.

### 5.1 OpenAI-compatible: `POST /api/v1/chat/completions`

OpenAI-compatible request/response. Supports `stream: true` (SSE). Model resolved against active providers filtered by key's `allowed_providers`/`allowed_models`.

**Request body**:

```json
{
  "model": "deepseek-chat",
  "messages": [
    {"role": "system", "content": "You are helpful."},
    {"role": "user", "content": "Hello"}
  ],
  "stream": true,
  "temperature": 0.7,
  "max_tokens": 4096
}
```

**Non-streaming response**: Standard OpenAI chat completion JSON.

**Streaming response** (`stream: true`): SSE format with `data: {...}\n\n` chunks. Final chunk: `data: [DONE]\n\n`.

### 5.2 OpenAI-compatible: `GET /api/v1/models`

Returns available models for the authenticated key in OpenAI list format:

```json
{
  "object": "list",
  "data": [
    {"id": "deepseek-chat", "object": "model", "owned_by": "deepseek"},
    {"id": "gpt-4o", "object": "model", "owned_by": "openai"}
  ]
}
```

### 5.3 Anthropic-compatible: `POST /api/v1/messages`

Anthropic Messages API compatible endpoint. Allows consumers using the Anthropic SDK (`@anthropic-ai/sdk`, `anthropic` Python package) to use the gateway by pointing `base_url` to this server.

**Authentication**: Uses the same `Authorization: Bearer gsk_...` header (not `x-api-key` — the gateway normalizes this). Alternatively, accepts `x-api-key: gsk_...` header for drop-in Anthropic SDK compatibility.

**Request body**:

```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 1024,
  "system": "You are a helpful assistant.",
  "messages": [
    {"role": "user", "content": "Hello"}
  ],
  "stream": false,
  "temperature": 0.7
}
```

**Key differences from OpenAI format** (handled by the gateway):

| Feature | OpenAI format | Anthropic format |
|---|---|---|
| System prompt | `{"role": "system"}` in messages array | Top-level `"system"` field |
| Max tokens | `"max_tokens"` (optional) | `"max_tokens"` (required) |
| Streaming | `"stream": true` | `"stream": true` |
| Stop sequences | `"stop"` | `"stop_sequences"` |
| Response format | `choices[0].message` | `content[0].text` |
| Token usage | `usage.prompt_tokens` / `completion_tokens` | `usage.input_tokens` / `output_tokens` |
| Finish reason | `"stop"`, `"length"` | `"end_turn"`, `"max_tokens"` |
| Multi-turn content | string only | array of content blocks (`text`, `image`) |
| Thinking/reasoning | not standardized | `"thinking"` content blocks with `budget_tokens` |

**Non-streaming response**:

```json
{
  "id": "msg_...",
  "type": "message",
  "role": "assistant",
  "content": [
    {"type": "text", "text": "Hello! How can I help you today?"}
  ],
  "model": "claude-sonnet-4-20250514",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 25,
    "output_tokens": 15
  }
}
```

**Streaming response** (`stream: true`): SSE with Anthropic event types:

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_...","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-20250514",...}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":15}}

event: message_stop
data: {"type":"message_stop"}
```

### 5.4 Image Generation: `POST /api/v1/images/generations`

OpenAI Images API compatible endpoint. Proxies image generation requests to configured upstream image providers.

**Request body**:

```json
{
  "model": "dall-e-3",
  "prompt": "A white siamese cat sitting on a windowsill at sunset",
  "n": 1,
  "size": "1024x1024",
  "quality": "hd",
  "response_format": "url",
  "style": "natural"
}
```

**Parameters**:

| Parameter | Type | Notes |
|---|---|---|
| `model` | string | Required. Resolved against image-capable providers |
| `prompt` | string | Required. Text description of the image to generate |
| `n` | integer | Number of images (default: 1, max per admin config) |
| `size` | string | `256x256`, `512x512`, `1024x1024`, `1024x1792`, `1792x1024` |
| `quality` | string | `standard` or `hd` (provider-dependent) |
| `response_format` | string | `url` or `b64_json` |
| `style` | string | `natural` or `vivid` (provider-dependent) |

**Response**:

```json
{
  "created": 1710000000,
  "data": [
    {
      "url": "https://provider-cdn.example.com/generated-image.png",
      "revised_prompt": "A white siamese cat with blue eyes sitting on a wooden windowsill..."
    }
  ]
}
```

Or with `response_format: "b64_json"`:

```json
{
  "created": 1710000000,
  "data": [
    {
      "b64_json": "/9j/4AAQSkZJRgABAQ...",
      "revised_prompt": "..."
    }
  ]
}
```

**Provider normalization**: For non-OpenAI providers (Stability AI, Replicate, ComfyUI), the `ImagesController` translates between the OpenAI images format and the provider's native API. The Gateway's `ImageClient` module handles per-provider request/response translation:

- **Stability AI**: Maps `size` to `width`/`height`, `quality` to `cfg_scale`, sends multipart form
- **Together AI / CogView**: Already OpenAI-compatible, pass through
- **Replicate**: Maps to prediction API, polls for result, returns URL
- **ComfyUI**: Maps to workflow execution API, waits for output

### 5.5 OCR: `POST /api/v1/ocr`

Custom endpoint for extracting text from images. Not part of OpenAI or Anthropic standard APIs — this is a GSMLG gateway extension.

**Request body**:

```json
{
  "image": "data:image/png;base64,iVBORw0KGgo...",
  "model": "gpt-4o",
  "output_format": "markdown",
  "language": "en",
  "prompt": "Extract all text from this document, preserving table structure"
}
```

**Parameters**:

| Parameter | Type | Notes |
|---|---|---|
| `image` | string | Required. Base64 data URI or publicly accessible URL |
| `model` | string | Optional. Defaults to admin-configured OCR model |
| `output_format` | string | `text` (plain), `markdown` (structured), `json` (key-value). Default: `text` |
| `language` | string | Optional language hint (ISO 639-1). Helps with multi-language docs |
| `prompt` | string | Optional. Custom extraction instructions (appended to OCR system prompt) |
| `pages` | string | Optional. For multi-page PDFs: `"1-3"`, `"1,3,5"`. Default: all pages |

**Response**:

```json
{
  "id": "ocr_...",
  "model": "gpt-4o",
  "content": "# Invoice\n\n| Item | Qty | Price |\n|---|---|---|\n| Widget | 3 | $15.00 |",
  "output_format": "markdown",
  "usage": {
    "prompt_tokens": 1200,
    "completion_tokens": 85,
    "total_tokens": 1285
  },
  "metadata": {
    "language_detected": "en",
    "confidence": 0.97,
    "duration_ms": 2340
  }
}
```

**Implementation for vision LLM-based OCR**: The `OcrController` constructs a chat completion request with:

1. A system prompt from the admin-configured OCR template (or default: `"Extract all text from the provided image. Preserve formatting, tables, and structure."`)
2. A user message with the image as a content block:
   - OpenAI format: `{"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}`
   - Anthropic format: `{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "..."}}`
3. The output format instruction appended to system prompt (e.g., `"Output as markdown with tables."`)

This reuses the existing `AI.Client` and chat completion flow — OCR via vision LLMs is essentially a specialized chat completion with an image input.

**Implementation for dedicated OCR providers**: The `OcrClient` module handles provider-specific APIs:

- **Google Cloud Vision**: Sends `DOCUMENT_TEXT_DETECTION` request, maps `fullTextAnnotation` to structured output
- **Tesseract (self-hosted)**: Sends image to local Tesseract HTTP wrapper, returns plain text
- **PaddleOCR (self-hosted)**: Sends image to PaddleOCR server, returns detected text with coordinates

### 5.6 Agents: `POST /api/v1/agents/:agent_slug/chat`

Invoke a named agent. The agent's tools, system prompt, model, and parameters are preconfigured by admin. The caller only sends messages.

**Request body**:

```json
{
  "messages": [
    {"role": "user", "content": "What's the weather in Tokyo and convert it to a summary?"}
  ],
  "stream": true,
  "model": "gpt-4o",
  "max_iterations": 5
}
```

**Parameters**:

| Parameter | Type | Notes |
|---|---|---|
| `messages` | array | Required. Conversation messages |
| `stream` | boolean | Default: false. Stream the final response (tool loop runs server-side) |
| `model` | string | Optional. Overrides agent's default model |
| `max_iterations` | integer | Optional. Overrides agent's default (capped at agent's max) |
| `tool_choice` | string | Optional. Override: `"auto"`, `"required"`, `"none"`, or tool name |
| `additional_tools` | array | Optional. Extra tool definitions (passthrough only) from client |

**Non-streaming response** (all tools executed server-side):

```json
{
  "id": "agent_run_...",
  "agent": "weather-assistant",
  "model": "gpt-4o",
  "content": "The current weather in Tokyo is 18°C with partly cloudy skies...",
  "tool_calls_made": [
    {"tool": "get_weather", "arguments": {"location": "Tokyo"}, "duration_ms": 450},
    {"tool": "unit_convert", "arguments": {"value": 18, "from": "C", "to": "F"}, "duration_ms": 12}
  ],
  "iterations": 2,
  "usage": {
    "prompt_tokens": 580,
    "completion_tokens": 120,
    "total_tokens": 700
  }
}
```

**Streaming response**: When `stream: true`, the tool loop runs server-side transparently. The client receives SSE events for the **final text response only** (not intermediate tool calls). Tool call metadata is included in the final event:

```
event: agent_start
data: {"type":"agent_start","agent":"weather-assistant","model":"gpt-4o"}

event: tool_start
data: {"type":"tool_start","tool":"get_weather","arguments":{"location":"Tokyo"}}

event: tool_end
data: {"type":"tool_end","tool":"get_weather","duration_ms":450}

event: content_delta
data: {"type":"content_delta","delta":"The current weather in Tokyo is "}

event: content_delta
data: {"type":"content_delta","delta":"18°C with partly cloudy skies..."}

event: agent_end
data: {"type":"agent_end","iterations":2,"usage":{"prompt_tokens":580,"completion_tokens":120,"total_tokens":700}}
```

**Hybrid tool response** (some tools are `:passthrough`): If any tool calls are `:passthrough` type, the server pauses the loop and returns the tool calls to the client:

```json
{
  "id": "agent_run_...",
  "status": "requires_action",
  "required_action": {
    "type": "submit_tool_outputs",
    "tool_calls": [
      {"id": "call_abc", "function": {"name": "browser_search", "arguments": "{\"query\": \"Tokyo weather\"}"}}
    ]
  }
}
```

The client executes the tool, then sends back results via a follow-up request:

```json
{
  "agent_run_id": "agent_run_...",
  "tool_outputs": [
    {"tool_call_id": "call_abc", "output": "Tokyo: 18°C, partly cloudy"}
  ]
}
```

### 5.7 Agent Discovery: `GET /api/v1/agents`

List available agents for the authenticated key:

```json
{
  "data": [
    {
      "slug": "weather-assistant",
      "name": "Weather Assistant",
      "description": "Get weather information for any location",
      "model": "gpt-4o",
      "tools": ["get_weather", "unit_convert"],
      "max_iterations": 10
    },
    {
      "slug": "code-reviewer",
      "name": "Code Reviewer",
      "description": "Review code for bugs, style, and security issues",
      "model": "claude-sonnet-4-20250514",
      "tools": ["search_knowledge_base", "lint_code"],
      "max_iterations": 5
    }
  ]
}
```

### 5.8 Agent Detail: `GET /api/v1/agents/:agent_slug`

Returns agent configuration including tool schemas (for clients that want to inspect available tools).

### 5.9 Tool Use in Chat Endpoints

The chat endpoints (`/api/v1/chat/completions` and `/api/v1/messages`) also support tool use, independent of named agents:

**OpenAI format** — pass `tools` array in request, receive `tool_calls` in response:

```json
{
  "model": "gpt-4o",
  "messages": [{"role": "user", "content": "What's the weather?"}],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather for a location",
        "parameters": {"type": "object", "properties": {"location": {"type": "string"}}, "required": ["location"]}
      }
    }
  ],
  "tool_choice": "auto"
}
```

**Anthropic format** — pass `tools` array, receive `tool_use` content blocks:

```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 1024,
  "messages": [{"role": "user", "content": "What's the weather?"}],
  "tools": [
    {
      "name": "get_weather",
      "description": "Get weather for a location",
      "input_schema": {"type": "object", "properties": {"location": {"type": "string"}}, "required": ["location"]}
    }
  ]
}
```

**Admin-injected tools**: API keys can have tools attached (via `ai_api_key_tools` join table). These tools are automatically merged into every chat request for that key, similar to how system prompts are injected. If the caller also sends `tools`, both lists are merged (admin tools take priority on name conflicts).

### 5.10 Format Negotiation & Internal Normalization

The Gateway service works with a unified internal message format. Controllers are responsible for translating between the external API format and the internal format:

```
OpenAI request → [ChatCompletionsController] → normalize → Gateway → upstream provider
Anthropic request → [MessagesController] → normalize → Gateway → upstream provider

upstream response → Gateway → [Controller] → format-specific response
```

**Internal normalized format** (used by `AI.Gateway`):

```elixir
%{
  model: "deepseek-chat",
  system: "You are helpful.",         # extracted from messages or top-level
  messages: [%{role: :user, content: "Hello"}],
  tools: [%{name: "get_weather", description: "...", parameters: %{...}}],  # optional
  tool_choice: "auto",               # optional
  params: %{temperature: 0.7, max_tokens: 4096},
  stream: true
}
```

**Normalization rules**:

- **OpenAI → internal**: Extract `role: "system"` messages into `system` field; pass rest as `messages`
- **Anthropic → internal**: Map top-level `"system"` to `system` field; map `"stop_sequences"` to `"stop"`; flatten content blocks to strings for text-only providers
- **Internal → upstream**: The existing `AI.Client` already speaks OpenAI-compatible protocol to all upstream providers, so the internal format maps directly
- **Upstream → OpenAI response**: Pass through (already OpenAI format)
- **Upstream → Anthropic response**: Transform `choices[0].message` to `content` blocks; map `prompt_tokens`/`completion_tokens` to `input_tokens`/`output_tokens`; map finish reasons (`"stop"` → `"end_turn"`, `"length"` → `"max_tokens"`)
- **Tool format — OpenAI → internal**: `tools[].function.parameters` → `tools[].parameters`; `tool_calls[].function` → flat struct
- **Tool format — Anthropic → internal**: `tools[].input_schema` → `tools[].parameters`; `tool_use` content blocks → tool_calls struct
- **Tool format — internal → OpenAI**: Wrap in `{"type": "function", "function": {...}}`; tool results as `{"role": "tool", "tool_call_id": "..."}`
- **Tool format — internal → Anthropic**: Use `input_schema`; tool results as `{"role": "user", "content": [{"type": "tool_result", ...}]}`

---

## 6. Gateway Service — `GsmlgAppAdmin.AI.Gateway`

Core orchestration module that works with the normalized internal format (API-format-agnostic). Controllers handle format translation; the Gateway handles business logic. Three main entry points:

### `Gateway.chat(api_key, normalized_request, opts)`

For chat completions (both OpenAI and Anthropic surfaces):

```
1. Resolve provider + model (from request, filtered by key restrictions)
2. Fetch system prompt templates (defaults + key-specific)
3. Fetch memories (global + user + key scoped)
4. Render template variables ({{memory}}, {{date}}, etc.)
5. Merge admin system prompt with caller's system prompt (admin first)
6. Call AI.Client (streaming or non-streaming)
7. Log to ApiUsageLog (endpoint_type: :chat) + increment counters
8. Return unified result (controller converts to OpenAI or Anthropic format)
```

### `Gateway.generate_image(api_key, params, opts)`

For image generation:

```
1. Resolve image provider + model (from request, filtered by key restrictions)
2. Validate size, n, quality against key's allowed settings
3. Call ImageClient with provider-specific translation
4. Log to ApiUsageLog (endpoint_type: :image, images_generated: n)
5. Return generated image URLs or base64 data
```

### `Gateway.extract_text(api_key, params, opts)`

For OCR:

```
1. Resolve OCR provider (vision LLM or dedicated OCR service)
2. If vision LLM: construct chat request with OCR system prompt + image
3. If dedicated OCR: call OcrClient with provider-specific API
4. Log to ApiUsageLog (endpoint_type: :ocr)
5. Return extracted text in requested format (text/markdown/json)
```

### `Gateway.run_agent(api_key, agent, messages, opts)`

For named agent invocations:

```
1. Load agent with tools and templates
2. Resolve provider + model (agent default or request override)
3. Build system prompt (agent templates + agent memories + key memories + global)
4. Convert tools to internal format (OpenAI function calling schema)
5. Enter tool loop:
   a. Call LLM with messages + tools
   b. If response has tool_calls:
      - Separate :passthrough tools from executable tools
      - If :passthrough tools exist → return to client with requires_action
      - Execute server-side tools (webhook/builtin/code) in parallel where possible
      - Append tool results to messages
      - Increment iteration counter
      - If iteration < max_iterations → goto 5a
      - Else → force final response
   c. If response is final text → break loop
6. Log to ApiUsageLog (endpoint_type: :agent, all iterations summed)
7. Return final response + tool execution metadata
```

### `Gateway.execute_tool(tool, arguments, opts)`

Internal helper for server-side tool execution:

```
1. Check tool rate limit (ETS counter)
2. Based on execution_type:
   - :webhook → Req.post(tool.webhook_url, json: arguments, headers: tool.webhook_headers)
   - :builtin → apply(handler_module, :execute, [arguments])
   - :code → Code.eval_string(tool.code_body, [args: arguments], restricted_env)
   - :mcp → McpConnectionManager.call_tool(tool.mcp_server_id, tool.mcp_tool_name, arguments)
3. Apply timeout (tool.timeout_ms)
4. Return {:ok, result} or {:error, reason}
```

The Gateway never knows which external API format the request came from — it only works with normalized internal structs.

---

## 7. New Plugs

- **`ApiKeyAuth`** — extract token from `Authorization: Bearer` header or `x-api-key` header (Anthropic SDK compatibility), lookup by prefix, verify hash, check active/expiry, assign `api_key` + `api_user`. Returns 401 with format-appropriate error (detects API format from request path).
- **`RateLimit`** — ETS sliding window counters per key. Returns 429 with `Retry-After` header on exceed.
- **`CORS`** — configurable allowed origins, preflight `OPTIONS` handling.

---

## 8. Admin UI (LiveView)

All under existing `live_session :authenticated`, grouped under the `/ai-provider` base URL and `AiProviderLive` module namespace.

### 8.1 Navigation Structure

The admin sidebar organizes AI Provider settings into **grouped sections**, each with a section header and its own set of menu items. Tools, MCP Servers, and Agents are in **separate sections** — not inlined on the same row:

```
AI Provider
│
│  AI Chat               → /chat  (no section header, top-level entry)
│
├─ GATEWAY
│  ├── Providers         → /ai-provider/providers
│  ├── API Keys          → /ai-provider/api-keys
│  └── API Usage         → /ai-provider/usage
│
├─ PROMPTS & MEMORY
│  ├── System Prompts    → /ai-provider/system-prompts
│  └── Memories          → /ai-provider/memories
│
├─ TOOLS
│  ├── Tools             → /ai-provider/tools
│  └── MCP Servers       → /ai-provider/mcp-servers
│
└─ AGENTS
   └── Agents            → /ai-provider/agents
```

The **AI Chat** link sits at the top of the sidebar without a section header, providing quick access to the chat interface. The chat page has its own inner sidebar (conversation list, provider selector) so it is not wrapped in `ai_provider_layout` — it just links bidirectionally (chat sidebar has a "Settings" link back to `/ai-provider/providers`).

Section headers are rendered as small uppercase labels (`text-xs`, `uppercase`, `tracking-wider`) that visually separate each group. Each menu item is its own clickable row with an icon.

### 8.2 Routes

| Route | LiveView | Purpose |
|---|---|---|
| `/ai-provider/providers` | `AiProviderLive.ProviderSettings.Index` | List, create, edit providers |
| `/ai-provider/providers/new` | `AiProviderLive.ProviderSettings.Form` | Create new provider |
| `/ai-provider/providers/:id` | `AiProviderLive.ProviderSettings.Show` | Provider detail + usage stats |
| `/ai-provider/providers/:id/edit` | `AiProviderLive.ProviderSettings.Form` | Edit existing provider |
| `/ai-provider/api-keys` | `AiProviderLive.ApiKey.Index` | List, create (modal), edit, revoke |
| `/ai-provider/system-prompts` | `AiProviderLive.SystemPrompt.Index` | CRUD with variable reference |
| `/ai-provider/memories` | `AiProviderLive.Memory.Index` | Filterable by scope/category |
| `/ai-provider/tools` | `AiProviderLive.Tool.Index` | List, create, edit, test tools |
| `/ai-provider/tools/:id` | `AiProviderLive.Tool.Show` | Tool detail + execution logs |
| `/ai-provider/mcp-servers` | `AiProviderLive.McpServer.Index` | List, add, configure MCP servers |
| `/ai-provider/mcp-servers/:id` | `AiProviderLive.McpServer.Show` | Server detail, health, synced tools |
| `/ai-provider/agents` | `AiProviderLive.Agent.Index` | List, create, edit agents |
| `/ai-provider/agents/:id` | `AiProviderLive.Agent.Show` | Agent detail + test chat |
| `/ai-provider/usage` | `AiProviderLive.ApiUsage.Index` | Aggregated dashboard |

Follows existing modal CRUD pattern (patch-based navigation, `dm_modal`).

**API Key creation flow**: On create, the full key is displayed once with a copy button and a warning that it cannot be retrieved again.

**MCP Server management**:
- Form includes: name, slug, transport type selector (stdio/SSE/Streamable HTTP)
- Transport config: command + args + env for stdio; URL + headers for HTTP
- Secret interpolation support in env vars and headers (`{{secret:key}}`)
- **Connect/disconnect** button with real-time health indicator
- **Auto-discovered tools list**: shows all tools from `tools/list`, with toggle to enable/disable individual tools
- **Resources list**: shows available MCP resources, linkable to template variables
- **Connection log**: recent connection events, errors, reconnection attempts

**Tool management**:
- Form includes: name, slug, description, execution type selector, JSON Schema editor for parameters
- Webhook config: URL, method, headers (with secret interpolation preview)
- Builtin handler: dropdown of registered handler modules
- Code editor: syntax-highlighted Elixir code textarea with sandboxing warnings
- MCP tools: shown with "MCP" badge and linked server name; schema is read-only (synced from server), description is overridable
- **Source indicator**: badge showing if tool is manually created or auto-synced from MCP
- **Test panel**: Execute tool with sample arguments, see response in real-time

**Agent management**:
- Form includes: name, slug, description, model/provider selector, max_iterations, tool_choice
- **Tool picker**: Drag-and-drop ordered list of available tools. Toggle individual tools on/off
- **Template picker**: Select system prompt templates to attach
- **Memory section**: Create/manage agent-scoped memories inline
- **Test chat panel**: Interactive chat directly in the admin UI that exercises the full agent loop, showing tool calls and results in real-time

---

## 9. Data Flow

```
Client (OpenAI SDK, Anthropic SDK, or custom)
    |
    | POST /api/v1/chat/completions      ← OpenAI chat format (+ optional tools)
    | POST /api/v1/messages              ← Anthropic chat format (+ optional tools)
    | POST /api/v1/images/generations    ← Image generation
    | POST /api/v1/ocr                   ← OCR extraction
    | POST /api/v1/agents/:slug/chat     ← Agent invocation
    | GET  /api/v1/agents                ← List agents
    | Authorization: Bearer gsk_... or x-api-key: gsk_...
    |
    v
[ApiKeyAuth Plug] ── 401 if invalid (format-aware error)
    |
[RateLimit Plug] ── 429 if exceeded
    |
[CORS Plug] ── headers
    |
    v
┌───────────────────────────────────────────────────────────────────┐
│                         Controllers                                │
│                                                                    │
│  [ChatCompletionsController]  [MessagesController]                 │
│       normalize OpenAI ──┐  ┌── normalize Anthropic                │
│       (+ tools/funcs)    v  v    (+ tools)                         │
│                   [Gateway.chat/3]                                  │
│                   → inject admin tools + system prompts + memories  │
│                   → AI.Client → upstream                           │
│                                                                    │
│  [AgentController]                                                 │
│       load agent + tools ──→ [Gateway.run_agent/4]                 │
│                              → build system prompt + tools          │
│                              → tool execution loop:                │
│                                 LLM call → tool_calls?             │
│                                 → execute server-side tools        │
│                                 → append results → repeat          │
│                              → return final answer + metadata      │
│                                                                    │
│  [ImagesController]                                                │
│       validate params ──→ [Gateway.generate_image/3]               │
│                           → ImageClient → upstream                 │
│                                                                    │
│  [OcrController]                                                   │
│       validate image ───→ [Gateway.extract_text/3]                 │
│                           → vision LLM or OcrClient                │
│                                                                    │
│  All paths → log usage, increment counters                         │
└───────────────────────────────────────────────────────────────────┘
    |
    v
  Format-specific response (OpenAI / Anthropic / Image / OCR / Agent JSON)
```

---

## 10. Security

1. **Key storage**: hash-only, prefix for lookup, shown once at creation
2. **Provider isolation**: upstream API keys never exposed to external consumers
3. **Scope enforcement**: per-key scope restrictions on endpoints
4. **Provider/model restriction**: keys lockable to specific providers and models
5. **Rate limiting**: per-key RPM/RPD with ETS counters
6. **CORS**: configurable per environment
7. **Input validation**: message count + content length limits
8. **Audit trail**: every request logged with IP, key, provider, status
9. **Key expiry**: optional `expires_at` for time-limited keys
10. **Tool execution sandboxing**: `:code` type tools run in restricted environment — no filesystem access, no network access beyond allowed hosts, execution timeout enforced
11. **Webhook SSRF prevention**: webhook tool URLs validated against allowlist of external hosts; private/internal IPs blocked by default
12. **Agent iteration limits**: hard cap on max_iterations (25) prevents runaway loops and excessive token consumption
13. **Tool secret management**: webhook auth headers use `{{secret:key}}` interpolation — secrets stored separately from tool definitions, never exposed in API responses or logs
14. **Per-tool rate limiting**: individual tool invocation limits prevent abuse of expensive external APIs
15. **MCP server isolation**: stdio MCP servers run as separate OS processes; HTTP MCP servers connect over TLS. MCP server credentials (env vars, headers) use `{{secret:key}}` interpolation and are never exposed in API responses
16. **MCP tool approval**: auto-discovered tools from MCP servers are active by default but can be individually disabled by admin before being exposed to agents/users

---

## 11. Configuration

```elixir
config :gsmlg_app_admin, GsmlgAppAdmin.AI.Gateway,
  default_rate_limit_rpm: 60,
  default_rate_limit_rpd: 1000,
  max_messages_per_request: 100,
  max_content_length: 32_000,
  max_agent_iterations: 25,
  tool_execution_timeout_ms: 30_000,
  webhook_allowed_hosts: [],             # empty = allow all external; blocks private IPs by default
  code_tool_enabled: false,              # disabled by default for safety
  mcp_tool_sync_interval_ms: 300_000,   # re-sync MCP tools every 5 minutes
  mcp_stdio_max_servers: 10,            # limit concurrent stdio MCP processes
  mcp_connection_timeout_ms: 10_000,    # timeout for MCP server connection
  cors_allowed_origins: ["*"]
```

---

## 12. Implementation Phases

**Phase 1 — Foundation** (API Key + Auth + OpenAI chat endpoint):

- `ApiKey` Ash resource + migration
- `ApiKeyAuth` plug (Bearer + x-api-key), `CORS` plug
- Internal normalized request/response structs
- `ChatCompletionsController` (OpenAI format, basic pass-through, no prompt injection)
- `ModelsController`
- End-to-end verification: create key → curl → AI response

**Phase 2 — Anthropic API Surface**:

- `MessagesController` with Anthropic format normalization
- Anthropic → internal request translation (top-level `system`, content blocks, `stop_sequences`)
- Internal → Anthropic response translation (content blocks, `input_tokens`/`output_tokens`, event-based SSE)
- Anthropic streaming format (message_start, content_block_delta, message_stop events)
- End-to-end verification: Anthropic Python SDK → gateway → AI response

**Phase 3 — System Prompts + Memory**:

- `SystemPromptTemplate` resource + migration
- `Memory` resource + migration
- `ApiKeyTemplate` join resource
- `AI.Gateway` module with full chat orchestration
- Wire both chat controllers through Gateway

**Phase 4 — Image Generation API**:

- `ImageClient` module with per-provider translation (DALL-E, Stability AI, CogView, Replicate, ComfyUI)
- `ImagesController` with OpenAI Images API format
- `Gateway.generate_image/3` with provider resolution + validation
- Provider presets for image providers (similar to existing chat provider presets)
- End-to-end verification: OpenAI SDK `client.images.generate()` → gateway → image

**Phase 5 — OCR API**:

- `OcrClient` module for dedicated OCR providers (Google Cloud Vision, Tesseract, PaddleOCR)
- Vision LLM OCR path (reuses chat completion flow with image content blocks)
- `OcrController` with request validation + image handling (base64, URL)
- `Gateway.extract_text/3` with provider routing
- Default OCR system prompt template
- End-to-end verification: curl with base64 image → gateway → extracted text

**Phase 6 — Tool Definitions**:

- `AI.Tool` Ash resource + migration
- Admin UI: AiProviderLive.Tool.Index (CRUD + JSON Schema editor)
- Tool execution engine: webhook executor, builtin handler registry
- Tool test panel in admin UI (execute with sample args)
- Webhook SSRF prevention (private IP blocking)

**Phase 7 — MCP Integration**:

- `AI.McpServer` Ash resource + migration
- `McpConnectionManager` GenServer — manages connections to MCP servers
- MCP client: stdio transport (Port-based process management)
- MCP client: SSE transport (HTTP long-polling)
- MCP client: Streamable HTTP transport
- `tools/list` → auto-sync to `AI.Tool` records with `execution_type: :mcp`
- `tools/call` → execute MCP tools during agent runs
- `resources/list` → expose as template variables
- Admin UI: AiProviderLive.McpServer.Index (add server, view health, manage synced tools)
- Connection health monitoring + auto-reconnect

**Phase 8 — Agents**:

- `AI.Agent` Ash resource + migration
- `AI.AgentTool`, `AI.AgentTemplate` join resources
- `Gateway.run_agent/4` with tool execution loop (including MCP tools)
- `AgentController` with chat, index, show, tools endpoints
- Agent streaming (tool_start/tool_end/content_delta/agent_end events)
- Admin UI: AiProviderLive.Agent.Index with tool picker (manual + MCP tools), template picker, test chat panel

**Phase 9 — Tool Use in Chat API**:

- Tool passthrough in `ChatCompletionsController` (OpenAI format tools/tool_calls)
- Tool passthrough in `MessagesController` (Anthropic format tools/tool_use)
- Tool format normalization (OpenAI ↔ Anthropic ↔ internal)
- Admin-injected tools per API key (ai_api_key_tools join table)

**Phase 10 — Rate Limiting + Usage Tracking**:

- `ApiUsageLog` resource + migration (with `endpoint_type`, `images_generated`, `agent_id` fields)
- `RateLimit` plug with ETS counters
- Per-tool rate limiting
- Usage logging in Gateway (all entry points: chat, image, ocr, agent)
- Counter increments on ApiKey

**Phase 11 — Admin UI**:

- API Key management LiveView
- System Prompt Template LiveView
- Memory management LiveView
- Usage dashboard LiveView (with endpoint_type breakdown: chat/image/ocr/agent)
- Image provider configuration in existing provider settings
- Sidebar navigation links

**Phase 12 — Polish**:

- SSE re-streaming for both chat formats (OpenAI + Anthropic)
- `:code` tool execution sandboxing (optional, disabled by default)
- Error handling edge cases (format-aware error responses)
- Tests for plugs, gateway, all controllers, client modules, and tool executors
- API consumer documentation (SDK examples for chat, image, OCR, agents)

---

## 13. Critical Files

| File | Purpose |
|---|---|
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/ai.ex` | Register new resources (ApiKey, Tool, Agent, etc.), add domain functions |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/router.ex` | Add api_gateway pipeline, /api/v1 scope, LiveView routes under /ai-provider |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/client.ex` | Existing upstream chat client — Gateway delegates to this for chat + tool use |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/gateway.ex` | New — core orchestration (chat, generate_image, extract_text, run_agent) |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/tool_executor.ex` | New — tool execution engine (webhook, builtin, code handlers) |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/image_client.ex` | New — upstream image generation client with per-provider translation |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/ocr_client.ex` | New — dedicated OCR provider client |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/tool.ex` | New — Tool Ash resource |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/agent.ex` | New — Agent Ash resource |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/mcp_server.ex` | New — MCP Server Ash resource |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/mcp_connection_manager.ex` | New — GenServer managing MCP server connections + tool sync |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/mcp_client.ex` | New — MCP protocol client (stdio, SSE, Streamable HTTP transports) |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider.ex` | Reference pattern for Ash resources; may need `provider_type` field |
| `apps/gsmlg_app_admin/lib/gsmlg_app_admin/ai/provider_presets.ex` | Add image + OCR provider presets |
| `apps/gsmlg_app_admin_web/lib/gsmlg_app_admin_web/live/ai_provider_live/` | All AI provider LiveViews under `AiProviderLive.*` namespace |

## 14. Dependencies

No new Hex dependencies required. Existing stack covers all needs: `Req` (HTTP client for all upstream APIs), `Jason` (JSON), `Ash`/`AshPostgres` (resources), ETS (rate limiting). Image data handling (base64 encode/decode) uses Elixir's built-in `Base` module.
