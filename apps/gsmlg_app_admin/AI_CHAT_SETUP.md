# AI Chat Feature Setup Guide

This guide explains how to set up and use the AI Chat feature in the GSMLG Admin application.

## Overview

The AI Chat feature provides a chat interface with support for multiple AI providers:
- **DeepSeek** - Advanced language models with coding capabilities
- **Zhipu AI (ChatGLM)** - Strong Chinese language and coding support
- **Moonshot AI (Kimi)** - Long context models (up to 128K tokens)
- **OpenAI** - GPT models (optional)

## Features

- ✅ Multiple AI provider support
- ✅ Real-time streaming responses
- ✅ Conversation history management
- ✅ Provider switching in UI
- ✅ System prompts and model parameters
- ✅ Persistent chat storage

## Database Setup

The migrations have already been run. The following tables are available:
- `ai_providers` - AI provider configurations
- `conversations` - Chat sessions
- `messages` - Individual chat messages

## Seed Data

AI providers have been seeded with placeholder API keys. Run the seed file to populate:

```bash
mix run apps/gsmlg_app_admin/priv/repo/seeds_ai_providers.exs
```

## API Key Configuration

### Option 1: Environment Variables (Recommended)

Set environment variables for the providers you want to use:

```bash
export DEEPSEEK_API_KEY="sk-your-deepseek-key"
export ZHIPU_API_KEY="your-zhipu-key"
export MOONSHOT_API_KEY="sk-your-moonshot-key"
export OPENAI_API_KEY="sk-your-openai-key"
```

Then restart the application.

### Option 2: Database Update

Update API keys directly in the database:

```elixir
# In IEx console
alias GsmlgAppAdmin.AI.Provider

# Update DeepSeek API key
{:ok, provider} = Provider |> Ash.Query.filter(slug == "deepseek") |> Ash.read_one()
provider
|> Ash.Changeset.for_update(:update, %{
  api_key: "sk-your-actual-key",
  is_active: true
})
|> Ash.update()
```

### Getting API Keys

- **DeepSeek**: https://platform.deepseek.com/
- **Zhipu AI**: https://open.bigmodel.cn/
- **Moonshot AI**: https://platform.moonshot.cn/
- **OpenAI**: https://platform.openai.com/

## Usage

1. **Start the server**:
   ```bash
   mix phx.server
   ```

2. **Access the admin panel**:
   Navigate to `http://localhost:4153`

3. **Sign in** with your admin credentials

4. **Click "AI Chat"** in the navigation menu

5. **Select a provider** from the dropdown (ensure it has a valid API key)

6. **Start chatting!**

## Project Structure

```
apps/gsmlg_app_admin/
├── lib/gsmlg_app_admin/ai/
│   ├── ai.ex                 # AI domain
│   ├── client.ex             # OpenAI-compatible API client
│   ├── conversation.ex       # Conversation resource
│   ├── message.ex            # Message resource
│   └── provider.ex           # Provider resource
└── priv/repo/
    ├── migrations/
    │   ├── 20251118172233_add_ai_tables_extensions_1.exs
    │   └── 20251118172235_add_ai_tables.exs
    └── seeds_ai_providers.exs

apps/gsmlg_app_admin_web/
└── lib/gsmlg_app_admin_web/
    └── live/chat_live/
        └── index.ex          # Chat LiveView interface
```

## Troubleshooting

### "Please configure an API key" error

Make sure you've set the API key for the selected provider either via environment variables or database update.

### Providers show as inactive

Providers are set to inactive by default if no API key is provided. Either:
1. Set environment variable and restart
2. Update the provider's `is_active` field to `true` after adding the API key

### No response from AI

Check:
1. API key is valid
2. You have credits/quota with the provider
3. The provider's API endpoint is accessible
4. Check logs for any error messages

## API Endpoints

All providers use OpenAI-compatible endpoints:

- **DeepSeek**: `https://api.deepseek.com/v1`
- **Zhipu AI**: `https://open.bigmodel.cn/api/paas/v4`
- **Moonshot AI**: `https://api.moonshot.cn/v1`
- **OpenAI**: `https://api.openai.com/v1`

## Customization

### Adding a New Provider

1. Create a new provider record via IEx or the admin interface
2. Ensure `slug`, `api_base_url`, `api_key`, and `model` are set
3. Set `is_active` to `true`

### Changing Model Parameters

Update the `default_params` field in the provider record:

```elixir
provider
|> Ash.Changeset.for_update(:update, %{
  default_params: %{
    "temperature" => 0.8,
    "max_tokens" => 2048,
    "top_p" => 0.9
  }
})
|> Ash.update()
```

## Support

For issues or questions about the AI Chat feature, check:
- Application logs: `tail -f .devenv/processes.log`
- Database state: Connect to PostgreSQL on port 5433
- API provider status pages
