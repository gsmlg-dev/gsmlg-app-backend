defmodule GsmlgAppAdmin.AI.ProviderPresets do
  @moduledoc """
  Predefined provider configurations for common LLM providers.

  Supports providers via ReqLLM's unified interface and other OpenAI-compatible APIs.
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
      model: "gpt-5.4",
      available_models: [
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.4-nano",
        "gpt-5",
        "gpt-5-mini",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "gpt-4o",
        "gpt-4o-mini",
        "o4-mini",
        "o3",
        "o3-pro",
        "o3-mini",
        "o1",
        "o1-pro"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "OpenAI - GPT-5.4 flagship and O-series reasoning models"
    },
    %{
      id: "anthropic",
      name: "Anthropic",
      slug: "anthropic",
      api_base_url: "https://api.anthropic.com/v1",
      model: "claude-sonnet-4-6",
      available_models: [
        "claude-opus-4-6",
        "claude-sonnet-4-6",
        "claude-haiku-4-5",
        "claude-opus-4-5",
        "claude-sonnet-4-5",
        "claude-opus-4-20250514",
        "claude-sonnet-4-20250514"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Anthropic - Claude 4.6 with advanced reasoning and 1M context"
    },
    %{
      id: "google",
      name: "Google (Gemini)",
      slug: "google",
      api_base_url: "https://generativelanguage.googleapis.com/v1beta",
      model: "gemini-2.5-flash",
      available_models: [
        "gemini-3.1-pro-preview",
        "gemini-3.1-flash-lite-preview",
        "gemini-3-flash-preview",
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Google Gemini - Multimodal AI models up to Gemini 3.1"
    },
    %{
      id: "deepseek",
      name: "DeepSeek",
      slug: "deepseek",
      api_base_url: "https://api.deepseek.com/v1",
      model: "deepseek-chat",
      available_models: ["deepseek-chat", "deepseek-reasoner"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096, "top_p" => 1.0},
      description: "DeepSeek - V3.2 chat and R1 reasoning models (128K context)"
    },
    %{
      id: "zhipu",
      name: "Zhipu AI (GLM)",
      slug: "zhipu",
      api_base_url: "https://open.bigmodel.cn/api/paas/v4",
      model: "glm-4-plus",
      available_models: [
        "glm-4-plus",
        "glm-4-long",
        "glm-4-air",
        "glm-4-airx",
        "glm-4-flash",
        "glm-4-flashx",
        "codegeex-4"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096, "top_p" => 0.7},
      description: "Zhipu AI - GLM-4 models with strong Chinese and coding support"
    },
    %{
      id: "moonshot",
      name: "Moonshot AI (Kimi)",
      slug: "moonshot",
      api_base_url: "https://api.moonshot.cn/v1",
      model: "kimi-latest",
      available_models: [
        "kimi-latest",
        "moonshot-v1-8k",
        "moonshot-v1-32k",
        "moonshot-v1-128k"
      ],
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
        "meta-llama/llama-4-maverick-17b-128e-instruct",
        "meta-llama/llama-4-scout-17b-16e-instruct",
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "qwen/qwen-3-32b",
        "deepseek-r1-distill-llama-70b",
        "qwen-qwq-32b"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Groq - Ultra-fast inference on LPU hardware"
    },
    %{
      id: "openrouter",
      name: "OpenRouter",
      slug: "openrouter",
      api_base_url: "https://openrouter.ai/api/v1",
      model: "anthropic/claude-sonnet-4-6",
      available_models: [
        "anthropic/claude-opus-4-6",
        "anthropic/claude-sonnet-4-6",
        "openai/gpt-5.4",
        "openai/gpt-4.1",
        "openai/o3",
        "openai/o4-mini",
        "google/gemini-2.5-pro",
        "google/gemini-2.5-flash",
        "deepseek/deepseek-chat",
        "deepseek/deepseek-reasoner",
        "meta-llama/llama-4-maverick"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "OpenRouter - Unified API for multiple LLM providers"
    },
    %{
      id: "xai",
      name: "xAI (Grok)",
      slug: "xai",
      api_base_url: "https://api.x.ai/v1",
      model: "grok-4",
      available_models: [
        "grok-4",
        "grok-4-fast-reasoning",
        "grok-4-fast-non-reasoning",
        "grok-code-fast-1",
        "grok-3",
        "grok-3-mini",
        "grok-2-1212",
        "grok-2-vision-1212"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "xAI - Grok 4 models with reasoning and real-time knowledge"
    },
    %{
      id: "cerebras",
      name: "Cerebras",
      slug: "cerebras",
      api_base_url: "https://api.cerebras.ai/v1",
      model: "qwen3-235b-a22b",
      available_models: [
        "qwen3-235b-a22b",
        "qwen3-32b",
        "qwen3-coder-480b",
        "llama3.3-70b",
        "llama3.1-8b",
        "deepseek-r1-distill-llama-70b",
        "gpt-oss-120b"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Cerebras - Ultra-fast inference with wafer-scale hardware"
    },
    %{
      id: "azure",
      name: "Azure OpenAI",
      slug: "azure-openai",
      api_base_url: "https://YOUR_RESOURCE.openai.azure.com/openai/deployments/YOUR_DEPLOYMENT",
      model: "gpt-4o",
      available_models: ["gpt-4o", "gpt-4o-mini", "o3-mini", "o4-mini"],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Azure OpenAI - Enterprise-grade OpenAI models on Azure"
    },
    %{
      id: "aws_bedrock",
      name: "AWS Bedrock",
      slug: "aws-bedrock",
      api_base_url: "https://bedrock-runtime.us-east-1.amazonaws.com",
      model: "anthropic.claude-sonnet-4-6-20260217-v1:0",
      available_models: [
        "anthropic.claude-opus-4-6-20260204-v1:0",
        "anthropic.claude-sonnet-4-6-20260217-v1:0",
        "anthropic.claude-haiku-4-5-20251101-v1:0",
        "anthropic.claude-sonnet-4-20250514-v1:0",
        "meta.llama4-maverick-17b-128e-instruct-v1:0",
        "meta.llama3-3-70b-instruct-v1:0"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "AWS Bedrock - Multiple model families on AWS infrastructure"
    },
    %{
      id: "together",
      name: "Together AI",
      slug: "together",
      api_base_url: "https://api.together.xyz/v1",
      model: "meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8",
      available_models: [
        "meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8",
        "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        "Qwen/Qwen3.5-397B-A17B",
        "Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8",
        "Qwen/Qwen2.5-72B-Instruct-Turbo",
        "deepseek-ai/DeepSeek-R1",
        "deepseek-ai/DeepSeek-V3",
        "mistralai/Mistral-Small-24B-Instruct-2501"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Together AI - Open source models with fast inference"
    },
    %{
      id: "fireworks",
      name: "Fireworks AI",
      slug: "fireworks",
      api_base_url: "https://api.fireworks.ai/inference/v1",
      model: "accounts/fireworks/models/llama4-maverick-instruct-basic",
      available_models: [
        "accounts/fireworks/models/llama4-maverick-instruct-basic",
        "accounts/fireworks/models/llama4-scout-instruct-basic",
        "accounts/fireworks/models/llama-v3p3-70b-instruct",
        "accounts/fireworks/models/qwen3-235b-a22b",
        "accounts/fireworks/models/qwen3-coder-480b-a35b-instruct",
        "accounts/fireworks/models/deepseek-v3p1",
        "accounts/fireworks/models/deepseek-r1-0528",
        "accounts/fireworks/models/gpt-oss-120b"
      ],
      default_params: %{"temperature" => 0.7, "max_tokens" => 4096},
      description: "Fireworks AI - Optimized open source model inference"
    },
    %{
      id: "ollama",
      name: "Ollama (Local)",
      slug: "ollama",
      api_base_url: "http://localhost:11434/v1",
      model: "llama4",
      available_models: [
        "llama4",
        "llama3.3",
        "qwen3",
        "qwen3:235b",
        "qwen2.5-coder",
        "deepseek-r1",
        "deepseek-v3",
        "gpt-oss",
        "gemma3",
        "mistral",
        "codestral"
      ],
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
