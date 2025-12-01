# Script for populating the database with AI provider configurations.
# You can run it as:
#
#     mix run apps/gsmlg_app_admin/priv/repo/seeds_ai_providers.exs
#
# Or from IEx:
#
#     iex> Code.eval_file("apps/gsmlg_app_admin/priv/repo/seeds_ai_providers.exs")

alias GsmlgAppAdmin.AI.Provider

# DeepSeek AI Provider
{:ok, _deepseek} =
  Provider
  |> Ash.Changeset.for_create(:create, %{
    name: "DeepSeek",
    slug: "deepseek",
    api_base_url: "https://api.deepseek.com/v1",
    api_key: System.get_env("DEEPSEEK_API_KEY") || "sk-placeholder-configure-via-env",
    model: "deepseek-chat",
    available_models: ["deepseek-chat", "deepseek-coder"],
    default_params: %{
      "temperature" => 0.7,
      "max_tokens" => 4096,
      "top_p" => 1.0
    },
    is_active: System.get_env("DEEPSEEK_API_KEY") != nil,
    description: "DeepSeek AI - Advanced language models with coding capabilities"
  })
  |> Ash.create()

IO.puts("✓ Created DeepSeek provider")

# Zhipu AI (ChatGLM) Provider
{:ok, _zhipu} =
  Provider
  |> Ash.Changeset.for_create(:create, %{
    name: "Zhipu AI (ChatGLM)",
    slug: "zhipu",
    api_base_url: "https://open.bigmodel.cn/api/paas/v4",
    api_key: System.get_env("ZHIPU_API_KEY") || "sk-placeholder-configure-via-env",
    model: "glm-4",
    available_models: ["glm-4", "glm-4-plus", "glm-4-air", "glm-3-turbo", "codegeex-4"],
    default_params: %{
      "temperature" => 0.7,
      "max_tokens" => 4096,
      "top_p" => 0.7
    },
    is_active: System.get_env("ZHIPU_API_KEY") != nil,
    description: "Zhipu AI - ChatGLM models with strong Chinese and coding support"
  })
  |> Ash.create()

IO.puts("✓ Created Zhipu AI provider")

# Moonshot AI Provider
{:ok, _moonshot} =
  Provider
  |> Ash.Changeset.for_create(:create, %{
    name: "Moonshot AI (Kimi)",
    slug: "moonshot",
    api_base_url: "https://api.moonshot.cn/v1",
    api_key: System.get_env("MOONSHOT_API_KEY") || "sk-placeholder-configure-via-env",
    model: "moonshot-v1-8k",
    available_models: [
      "moonshot-v1-8k",
      "moonshot-v1-32k",
      "moonshot-v1-128k"
    ],
    default_params: %{
      "temperature" => 0.3,
      "max_tokens" => 4096
    },
    is_active: System.get_env("MOONSHOT_API_KEY") != nil,
    description: "Moonshot AI (Kimi) - Long context AI models up to 128K tokens"
  })
  |> Ash.create()

IO.puts("✓ Created Moonshot AI provider")

# OpenAI Provider (as reference)
{:ok, _openai} =
  Provider
  |> Ash.Changeset.for_create(:create, %{
    name: "OpenAI",
    slug: "openai",
    api_base_url: "https://api.openai.com/v1",
    api_key: System.get_env("OPENAI_API_KEY") || "sk-placeholder-configure-via-env",
    model: "gpt-4o",
    available_models: [
      "gpt-4o",
      "gpt-4o-mini",
      "gpt-4-turbo",
      "gpt-3.5-turbo"
    ],
    default_params: %{
      "temperature" => 0.7,
      "max_tokens" => 4096
    },
    is_active: false,
    description: "OpenAI - GPT models (requires API key configuration)"
  })
  |> Ash.create()

IO.puts("✓ Created OpenAI provider")

IO.puts("\n✓ All AI providers seeded successfully!")
IO.puts("\nNote: API keys need to be configured via environment variables or admin interface:")
IO.puts("  - DEEPSEEK_API_KEY")
IO.puts("  - ZHIPU_API_KEY")
IO.puts("  - MOONSHOT_API_KEY")
IO.puts("  - OPENAI_API_KEY")
