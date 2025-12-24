defmodule GsmlgAppAdmin.AI.ProviderPresets do
  @moduledoc """
  Predefined provider configurations for common LLM providers.

  Supports providers from req_llm and other popular OpenAI-compatible APIs.
  """

  @presets [
    %{
      id: "generic",
      name: "Generic (OpenAI Compatible)",
      slug: "",
      api_base_url: "",
      model: "",
      available_models: [],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Custom OpenAI-compatible API provider"
    },
    %{
      id: "openai",
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com/v1",
      model: "gpt-4o",
      available_models: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo", "o1", "o1-mini"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "OpenAI - GPT and O1 reasoning models"
    },
    %{
      id: "anthropic",
      name: "Anthropic",
      slug: "anthropic",
      api_base_url: "https://api.anthropic.com/v1",
      model: "claude-sonnet-4-20250514",
      available_models: [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-opus-20240229"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Anthropic - Claude models with advanced reasoning"
    },
    %{
      id: "google",
      name: "Google (Gemini)",
      slug: "google",
      api_base_url: "https://generativelanguage.googleapis.com/v1beta",
      model: "gemini-2.0-flash",
      available_models: ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Google Gemini - Multimodal AI models"
    },
    %{
      id: "deepseek",
      name: "DeepSeek",
      slug: "deepseek",
      api_base_url: "https://api.deepseek.com/v1",
      model: "deepseek-chat",
      available_models: ["deepseek-chat", "deepseek-coder", "deepseek-reasoner"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096, "top_p" => 1.0},
      description: "DeepSeek - Advanced language models with coding capabilities"
    },
    %{
      id: "zhipu",
      name: "Zhipu AI (ChatGLM)",
      slug: "zhipu",
      api_base_url: "https://open.bigmodel.cn/api/paas/v4",
      model: "glm-4",
      available_models: ["glm-4", "glm-4-plus", "glm-4-air", "glm-3-turbo", "codegeex-4"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096, "top_p" => 0.7},
      description: "Zhipu AI - ChatGLM models with strong Chinese and coding support"
    },
    %{
      id: "moonshot",
      name: "Moonshot AI (Kimi)",
      slug: "moonshot",
      api_base_url: "https://api.moonshot.cn/v1",
      model: "moonshot-v1-8k",
      available_models: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
      default_params: %{"temperature" => 0.3, "max_tokens" => 4096},
      description: "Moonshot AI (Kimi) - Long context AI models up to 128K tokens"
    },
    %{
      id: "groq",
      name: "Groq",
      slug: "groq",
      api_base_url: "https://api.groq.com/openai/v1",
      model: "llama-3.3-70b-versatile",
      available_models: [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768",
        "gemma2-9b-it"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Groq - Ultra-fast inference on LPU hardware"
    },
    %{
      id: "openrouter",
      name: "OpenRouter",
      slug: "openrouter",
      api_base_url: "https://openrouter.ai/api/v1",
      model: "anthropic/claude-sonnet-4",
      available_models: [
        "anthropic/claude-sonnet-4",
        "openai/gpt-4o",
        "google/gemini-2.0-flash-001",
        "meta-llama/llama-3.3-70b-instruct"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "OpenRouter - Unified API for multiple LLM providers"
    },
    %{
      id: "xai",
      name: "xAI (Grok)",
      slug: "xai",
      api_base_url: "https://api.x.ai/v1",
      model: "grok-2",
      available_models: ["grok-2", "grok-2-mini", "grok-beta"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "xAI - Grok models with real-time knowledge"
    },
    %{
      id: "cerebras",
      name: "Cerebras",
      slug: "cerebras",
      api_base_url: "https://api.cerebras.ai/v1",
      model: "llama3.1-70b",
      available_models: ["llama3.1-70b", "llama3.1-8b"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Cerebras - Ultra-fast inference with wafer-scale hardware"
    },
    %{
      id: "azure",
      name: "Azure OpenAI",
      slug: "azure-openai",
      api_base_url: "https://YOUR_RESOURCE.openai.azure.com/openai/deployments/YOUR_DEPLOYMENT",
      model: "gpt-4o",
      available_models: ["gpt-4o", "gpt-4", "gpt-35-turbo"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Azure OpenAI - Enterprise-grade OpenAI models on Azure"
    },
    %{
      id: "aws_bedrock",
      name: "AWS Bedrock",
      slug: "aws-bedrock",
      api_base_url: "https://bedrock-runtime.us-east-1.amazonaws.com",
      model: "anthropic.claude-3-5-sonnet-20241022-v2:0",
      available_models: [
        "anthropic.claude-3-5-sonnet-20241022-v2:0",
        "anthropic.claude-3-haiku-20240307-v1:0",
        "meta.llama3-1-70b-instruct-v1:0"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "AWS Bedrock - Multiple model families on AWS infrastructure"
    },
    %{
      id: "together",
      name: "Together AI",
      slug: "together",
      api_base_url: "https://api.together.xyz/v1",
      model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
      available_models: [
        "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
        "Qwen/Qwen2.5-72B-Instruct-Turbo"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Together AI - Open source models with fast inference"
    },
    %{
      id: "fireworks",
      name: "Fireworks AI",
      slug: "fireworks",
      api_base_url: "https://api.fireworks.ai/inference/v1",
      model: "accounts/fireworks/models/llama-v3p3-70b-instruct",
      available_models: [
        "accounts/fireworks/models/llama-v3p3-70b-instruct",
        "accounts/fireworks/models/llama-v3p1-8b-instruct",
        "accounts/fireworks/models/qwen2p5-72b-instruct"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Fireworks AI - Optimized open source model inference"
    },
    %{
      id: "ollama",
      name: "Ollama (Local)",
      slug: "ollama",
      api_base_url: "http://localhost:11434/v1",
      model: "llama3.2",
      available_models: ["llama3.2", "llama3.1", "qwen2.5", "mistral", "codellama"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Ollama - Run open source models locally"
    }
  ]

  @doc """
  Returns all available provider presets.
  """
  def all, do: @presets

  @doc """
  Returns preset options formatted for select input.
  """
  def options do
    Enum.map(@presets, fn preset ->
      {preset.name, preset.id}
    end)
  end

  @doc """
  Gets a preset by its ID.
  """
  def get(id) do
    Enum.find(@presets, fn preset -> preset.id == id end)
  end

  @doc """
  Returns preset as a map suitable for form population.
  """
  def to_form_params(id) do
    case get(id) do
      nil ->
        %{}

      preset ->
        %{
          "name" => preset.name,
          "slug" => preset.slug,
          "api_base_url" => preset.api_base_url,
          "model" => preset.model,
          "available_models" => preset.available_models,
          "default_params" => preset.default_params,
          "description" => preset.description,
          "is_active" => true
        }
    end
  end
end
