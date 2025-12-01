# Add Mock AI provider for testing without API keys
alias GsmlgAppAdmin.AI.Provider

# Check if mock provider already exists
require Ash.Query

existing =
  Provider
  |> Ash.Query.filter(slug == "mock")
  |> Ash.read_one()

case existing do
  {:ok, nil} ->
    {:ok, _mock} =
      Provider
      |> Ash.Changeset.for_create(:create, %{
        name: "Mock AI (Testing)",
        slug: "mock",
        api_base_url: "http://localhost:4153/mock",
        api_key: "mock-key-no-api-needed",
        model: "mock-model-v1",
        available_models: ["mock-model-v1"],
        default_params: %{
          "temperature" => 0.7,
          "max_tokens" => 2048
        },
        is_active: true,
        description: "Mock AI provider for testing the chat interface without real API keys. Simulates streaming responses."
      })
      |> Ash.create()

    IO.puts("\n✓ Mock AI provider created successfully!")
    IO.puts("\nYou can now test the chat interface without configuring any API keys.")
    IO.puts("Just select 'Mock AI (Testing)' from the provider dropdown in the chat.")

  {:ok, _provider} ->
    IO.puts("\n✓ Mock AI provider already exists - no changes made.")

  {:error, error} ->
    IO.puts("\n✗ Error checking for existing mock provider:")
    IO.inspect(error)
end
