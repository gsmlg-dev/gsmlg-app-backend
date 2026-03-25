defmodule GsmlgAppAdmin.AI.MemoryTest do
  use GsmlgAppAdmin.DataCase, async: true

  alias GsmlgAppAdmin.AI.Memory

  describe "create - scope validations" do
    test "allows global scope without user_id" do
      {:ok, memory} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Global fact",
          category: :fact,
          scope: :global
        })
        |> Ash.create(authorize?: false)

      assert memory.scope == :global
      assert is_nil(memory.user_id)
    end

    test "rejects user scope without user_id" do
      result =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "User preference",
          category: :preference,
          scope: :user
        })
        |> Ash.create(authorize?: false)

      assert {:error, _} = result
    end

    test "allows user scope with user_id" do
      user_id = Ash.UUID.generate()

      {:ok, memory} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "User preference",
          category: :preference,
          scope: :user,
          user_id: user_id
        })
        |> Ash.create(authorize?: false)

      assert memory.scope == :user
      assert memory.user_id == user_id
    end

    test "rejects api_key scope without api_key_id" do
      result =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Key-specific context",
          category: :context,
          scope: :api_key
        })
        |> Ash.create(authorize?: false)

      assert {:error, _} = result
    end

    test "allows api_key scope with api_key_id" do
      key_id = Ash.UUID.generate()

      {:ok, memory} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Key-specific context",
          category: :context,
          scope: :api_key,
          api_key_id: key_id
        })
        |> Ash.create(authorize?: false)

      assert memory.scope == :api_key
      assert memory.api_key_id == key_id
    end

    test "rejects agent scope without agent_id" do
      result =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Agent instruction",
          category: :instruction,
          scope: :agent
        })
        |> Ash.create(authorize?: false)

      assert {:error, _} = result
    end

    test "allows agent scope with agent_id" do
      agent_id = Ash.UUID.generate()

      {:ok, memory} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Agent instruction",
          category: :instruction,
          scope: :agent,
          agent_id: agent_id
        })
        |> Ash.create(authorize?: false)

      assert memory.scope == :agent
      assert memory.agent_id == agent_id
    end
  end

  describe "for_request" do
    test "returns global memories" do
      {:ok, _} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Global info",
          category: :fact,
          scope: :global,
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, memories} = Memory.for_request(nil, nil, nil)
      assert Enum.any?(memories, &(&1.content == "Global info"))
    end

    test "excludes inactive memories" do
      {:ok, _} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Inactive global",
          category: :fact,
          scope: :global,
          is_active: false
        })
        |> Ash.create(authorize?: false)

      {:ok, memories} = Memory.for_request(nil, nil, nil)
      refute Enum.any?(memories, &(&1.content == "Inactive global"))
    end

    test "returns user-scoped memories when user_id provided" do
      user_id = Ash.UUID.generate()

      {:ok, _} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "User-specific info",
          category: :preference,
          scope: :user,
          user_id: user_id,
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, memories} = Memory.for_request(user_id, nil, nil)
      assert Enum.any?(memories, &(&1.content == "User-specific info"))

      # Does not appear for a different user_id
      {:ok, other_memories} = Memory.for_request(Ash.UUID.generate(), nil, nil)
      refute Enum.any?(other_memories, &(&1.content == "User-specific info"))
    end

    test "returns api_key-scoped memories when api_key_id provided" do
      api_key_id = Ash.UUID.generate()

      {:ok, _} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Key-specific instruction",
          category: :instruction,
          scope: :api_key,
          api_key_id: api_key_id,
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, memories} = Memory.for_request(nil, api_key_id, nil)
      assert Enum.any?(memories, &(&1.content == "Key-specific instruction"))

      # Does not appear for a different api_key_id
      {:ok, other_memories} = Memory.for_request(nil, Ash.UUID.generate(), nil)
      refute Enum.any?(other_memories, &(&1.content == "Key-specific instruction"))
    end

    test "returns agent-scoped memories when agent_id provided" do
      agent_id = Ash.UUID.generate()

      {:ok, _} =
        Memory
        |> Ash.Changeset.for_create(:create, %{
          content: "Agent context info",
          category: :context,
          scope: :agent,
          agent_id: agent_id,
          is_active: true
        })
        |> Ash.create(authorize?: false)

      {:ok, memories} = Memory.for_request(nil, nil, agent_id)
      assert Enum.any?(memories, &(&1.content == "Agent context info"))

      # Does not appear without agent_id
      {:ok, no_agent_memories} = Memory.for_request(nil, nil, nil)
      refute Enum.any?(no_agent_memories, &(&1.content == "Agent context info"))
    end
  end
end
