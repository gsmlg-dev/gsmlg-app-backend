defmodule GsmlgAppAdminWeb.Session.StoreTest do
  use ExUnit.Case, async: false

  alias GsmlgAppAdminWeb.Session.Store

  @moduletag :unit

  setup do
    # Clean up any existing sessions before each test
    :ets.delete_all_objects(Store.table_name())
    :ok
  end

  describe "table_name/0" do
    test "returns the ETS table name" do
      assert Store.table_name() == :gsmlg_admin_sessions
    end
  end

  describe "count/0" do
    test "returns 0 for empty table" do
      assert Store.count() == 0
    end

    test "returns count of all sessions" do
      # Insert sessions in Plug.Session.ETS format: {sid, data, timestamp}
      Enum.each(1..5, fn i ->
        sid = "session-#{i}"
        data = %{"user" => "user?id=user-#{i}"}
        timestamp = :erlang.timestamp()
        :ets.insert(Store.table_name(), {sid, data, timestamp})
      end)

      assert Store.count() == 5
    end
  end

  describe "count_active/0" do
    test "returns 0 for empty table" do
      assert Store.count_active() == 0
    end

    test "returns count of active sessions" do
      # Add 3 active sessions (recent timestamp)
      Enum.each(1..3, fn i ->
        sid = "active-session-#{i}"
        data = %{"user" => "user?id=user-#{i}"}
        timestamp = :erlang.timestamp()
        :ets.insert(Store.table_name(), {sid, data, timestamp})
      end)

      assert Store.count_active() == 3
    end

    test "excludes expired sessions from count" do
      # Add 3 active sessions
      Enum.each(1..3, fn i ->
        sid = "active-session-#{i}"
        data = %{"user" => "user?id=user-#{i}"}
        timestamp = :erlang.timestamp()
        :ets.insert(Store.table_name(), {sid, data, timestamp})
      end)

      # Add 2 expired sessions (timestamp from 9 hours ago)
      {mega, sec, micro} = :erlang.timestamp()
      expired_timestamp = {mega, sec - 9 * 60 * 60, micro}

      Enum.each(1..2, fn i ->
        sid = "expired-session-#{i}"
        data = %{"user" => "user?id=expired-#{i}"}
        :ets.insert(Store.table_name(), {sid, data, expired_timestamp})
      end)

      # Total count should be 5
      assert Store.count() == 5

      # Active count should only include non-expired sessions
      assert Store.count_active() == 3
    end
  end

  describe "cleanup/0" do
    test "removes expired sessions and returns count" do
      # Add 3 active sessions
      Enum.each(1..3, fn i ->
        sid = "active-session-#{i}"
        data = %{"user" => "user?id=user-#{i}"}
        timestamp = :erlang.timestamp()
        :ets.insert(Store.table_name(), {sid, data, timestamp})
      end)

      # Add 2 expired sessions
      {mega, sec, micro} = :erlang.timestamp()
      expired_timestamp = {mega, sec - 9 * 60 * 60, micro}

      Enum.each(1..2, fn i ->
        sid = "expired-session-#{i}"
        data = %{"user" => "user?id=expired-#{i}"}
        :ets.insert(Store.table_name(), {sid, data, expired_timestamp})
      end)

      # Cleanup should remove 2 expired sessions
      assert Store.cleanup() == 2

      # Only 3 active sessions should remain
      assert Store.count() == 3
      assert Store.count_active() == 3
    end

    test "returns 0 when no expired sessions" do
      # Add only active sessions
      Enum.each(1..3, fn i ->
        sid = "active-session-#{i}"
        data = %{"user" => "user?id=user-#{i}"}
        timestamp = :erlang.timestamp()
        :ets.insert(Store.table_name(), {sid, data, timestamp})
      end)

      assert Store.cleanup() == 0
      assert Store.count() == 3
    end
  end

  describe "Plug.Session.ETS compatibility" do
    test "works with Plug.Session.ETS record format" do
      # Plug.Session.ETS stores records as {sid, data, timestamp}
      sid = generate_session_id()
      data = %{"user" => "user?id=test-user-123", "_csrf_token" => "abc123"}
      timestamp = :erlang.timestamp()

      :ets.insert(Store.table_name(), {sid, data, timestamp})

      assert Store.count() == 1
      assert Store.count_active() == 1

      # Verify the record structure
      [{^sid, ^data, ^timestamp}] = :ets.lookup(Store.table_name(), sid)
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(96) |> Base.encode64(padding: false)
  end
end
