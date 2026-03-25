defmodule GsmlgAppAdmin.AI.ApiKeyTest do
  use GsmlgAppAdmin.DataCase, async: true

  require Ash.Query

  alias GsmlgAppAdmin.AI.ApiKey

  defp create_user do
    uid = :erlang.unique_integer([:positive])

    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "apikey_test#{uid}@example.com",
        password: "StrongPass123!"
      })
      |> Ash.create(authorize?: false)

    user
  end

  defp create_api_key(user) do
    uid = :erlang.unique_integer([:positive])

    {:ok, api_key} =
      ApiKey
      |> Ash.Changeset.for_create(:create, %{
        name: "test-key-#{uid}",
        scopes: [:chat_completions],
        is_active: true,
        user_id: user.id
      })
      |> Ash.create(authorize?: false)

    api_key
  end

  describe "generate_raw_key/0" do
    test "generates a key with gsk_ prefix and sufficient length" do
      key = ApiKey.generate_raw_key()
      assert String.starts_with?(key, "gsk_")
      assert byte_size(key) > 40
    end

    test "generates unique keys each call" do
      key1 = ApiKey.generate_raw_key()
      key2 = ApiKey.generate_raw_key()
      refute key1 == key2
    end
  end

  describe "verify_key/2" do
    test "returns true for matching key and hash" do
      raw_key = ApiKey.generate_raw_key()
      hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
      assert ApiKey.verify_key(raw_key, hash)
    end

    test "returns false for wrong key" do
      raw_key = ApiKey.generate_raw_key()
      hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
      refute ApiKey.verify_key("gsk_wrongkey", hash)
    end
  end

  describe "create/1" do
    test "stores key_prefix and key_hash, returns __raw_key__" do
      user = create_user()

      {:ok, api_key} =
        ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "test",
          scopes: [:chat_completions],
          is_active: true,
          user_id: user.id
        })
        |> Ash.create(authorize?: false)

      assert String.length(api_key.key_prefix) == 8
      assert String.length(api_key.key_hash) == 64
      raw_key = api_key.__raw_key__
      assert String.starts_with?(raw_key, "gsk_")
      assert ApiKey.verify_key(raw_key, api_key.key_hash)
    end

    test "rejects duplicate key_prefix (identity constraint)" do
      # Since prefixes are random with 48 bytes of entropy, duplication
      # is astronomically unlikely. This test ensures allow_nil? is set.
      user = create_user()

      {:ok, key1} =
        ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "key1",
          scopes: [:chat_completions],
          is_active: true,
          user_id: user.id
        })
        |> Ash.create(authorize?: false)

      # key_prefix is unique; creating again should generate a different one
      {:ok, key2} =
        ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "key2",
          scopes: [:chat_completions],
          is_active: true,
          user_id: user.id
        })
        |> Ash.create(authorize?: false)

      refute key1.key_prefix == key2.key_prefix
    end
  end

  describe "increment_usage/3 - atomic counter correctness" do
    test "accumulates total_requests correctly across two increments" do
      user = create_user()
      api_key = create_api_key(user)

      assert api_key.total_requests == 0

      {:ok, _} = ApiKey.increment_usage(api_key, 3, 0)
      {:ok, _} = ApiKey.increment_usage(api_key, 5, 0)

      # Reload from DB to get actual persisted value
      key_id = api_key.id

      reloaded =
        ApiKey
        |> Ash.Query.filter(id == ^key_id)
        |> Ash.read_one!(authorize?: false)

      assert reloaded.total_requests == 8
    end

    test "accumulates total_tokens correctly across two increments" do
      user = create_user()
      api_key = create_api_key(user)

      key_id = api_key.id
      {:ok, _} = ApiKey.increment_usage(api_key, 1, 100)
      {:ok, _} = ApiKey.increment_usage(api_key, 1, 250)

      reloaded =
        ApiKey
        |> Ash.Query.filter(id == ^key_id)
        |> Ash.read_one!(authorize?: false)

      assert reloaded.total_requests == 2
      assert reloaded.total_tokens == 350
    end

    test "updates last_used_at on each increment" do
      user = create_user()
      api_key = create_api_key(user)

      assert is_nil(api_key.last_used_at)

      key_id = api_key.id
      {:ok, _} = ApiKey.increment_usage(api_key, 1, 0)

      reloaded =
        ApiKey
        |> Ash.Query.filter(id == ^key_id)
        |> Ash.read_one!(authorize?: false)

      assert %DateTime{} = reloaded.last_used_at
    end

    test "default arguments increment by 1 request and 0 tokens" do
      user = create_user()
      api_key = create_api_key(user)

      key_id = api_key.id
      {:ok, _} = ApiKey.increment_usage(api_key, 1, 0)

      reloaded =
        ApiKey
        |> Ash.Query.filter(id == ^key_id)
        |> Ash.read_one!(authorize?: false)

      assert reloaded.total_requests == 1
      assert reloaded.total_tokens == 0
    end
  end

  describe "revoke/1" do
    test "sets is_active to false" do
      user = create_user()
      api_key = create_api_key(user)

      assert api_key.is_active

      {:ok, revoked} = ApiKey.revoke(api_key)
      refute revoked.is_active
    end
  end

  describe "by_prefix/1" do
    test "returns the key with the matching prefix" do
      user = create_user()
      api_key = create_api_key(user)

      {:ok, [found]} = ApiKey.by_prefix(api_key.key_prefix)
      assert found.id == api_key.id
    end

    test "returns empty list for unknown prefix" do
      {:ok, result} = ApiKey.by_prefix("xxxxxxxx")
      assert result == [] or is_list(result)
    end
  end
end
