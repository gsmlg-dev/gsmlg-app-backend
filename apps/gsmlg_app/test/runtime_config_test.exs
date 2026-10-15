defmodule GsmlgApp.RuntimeConfigTest do
  use ExUnit.Case, async: true

  @runtime_path Path.expand("../../../config/runtime.exs", __DIR__)
  @public_apps [:gsmlg_app, :gsmlg_app_web]
  @admin_apps [:gsmlg_app_admin, :gsmlg_app_admin_web]
  @public_env %{"SECRET_KEY_BASE" => String.duplicate("p", 64), "PORT" => "1324"}
  @admin_env %{
    "DATABASE_URL" => "ecto://test:test@localhost/test",
    "ADMIN_SECRET_KEY_BASE" => String.duplicate("a", 64),
    "TOKEN_SIGNING_SECRET" => String.duplicate("t", 64),
    "ADMIN_PORT" => "4321"
  }

  test "public release configures its endpoint without admin credentials" do
    config = read_config!(@public_apps, @public_env)

    assert config[:gsmlg_app_web][GsmlgAppWeb.Endpoint][:secret_key_base] ==
             @public_env["SECRET_KEY_BASE"]

    assert config[:gsmlg_app_web][GsmlgAppWeb.Endpoint][:http][:port] == 1324
    assert config[:gsmlg_app_web][GsmlgAppWeb.Endpoint][:server]
    refute Keyword.has_key?(config, :gsmlg_app_admin)
    refute Keyword.has_key?(config, :gsmlg_app_admin_web)
    refute Keyword.has_key?(config, :ash_authentication)
  end

  test "admin release configures its database and endpoint without a public secret" do
    config = read_config!(@admin_apps, @admin_env)

    assert config[:gsmlg_app_admin][GsmlgAppAdmin.Repo][:url] == @admin_env["DATABASE_URL"]

    assert config[:gsmlg_app_admin_web][GsmlgAppAdminWeb.Endpoint][:secret_key_base] ==
             @admin_env["ADMIN_SECRET_KEY_BASE"]

    assert config[:gsmlg_app_admin_web][GsmlgAppAdminWeb.Endpoint][:http][:port] == 4321

    assert config[:ash_authentication][:token_signing_secret] ==
             @admin_env["TOKEN_SIGNING_SECRET"]

    assert config[:ash_authentication][:jwt][:signing_secret] ==
             @admin_env["TOKEN_SIGNING_SECRET"]

    refute Keyword.has_key?(config, :gsmlg_app_web)
  end

  test "full release configures public and admin applications" do
    config = read_config!(@public_apps ++ @admin_apps, Map.merge(@public_env, @admin_env))

    assert config[:gsmlg_app_web][GsmlgAppWeb.Endpoint][:secret_key_base] ==
             @public_env["SECRET_KEY_BASE"]

    assert config[:gsmlg_app_admin][GsmlgAppAdmin.Repo][:url] == @admin_env["DATABASE_URL"]

    assert config[:gsmlg_app_admin_web][GsmlgAppAdminWeb.Endpoint][:secret_key_base] ==
             @admin_env["ADMIN_SECRET_KEY_BASE"]

    assert config[:ash_authentication][:token_signing_secret] ==
             @admin_env["TOKEN_SIGNING_SECRET"]
  end

  for {release, apps, environment, required} <- [
        {:public, @public_apps, @public_env, ["SECRET_KEY_BASE"]},
        {:admin, @admin_apps, @admin_env,
         ["DATABASE_URL", "ADMIN_SECRET_KEY_BASE", "TOKEN_SIGNING_SECRET"]},
        {:backend, @public_apps ++ @admin_apps, Map.merge(@public_env, @admin_env),
         ["SECRET_KEY_BASE", "DATABASE_URL", "ADMIN_SECRET_KEY_BASE", "TOKEN_SIGNING_SECRET"]}
      ],
      variable <- required do
    test "#{release} release requires #{variable}" do
      {output, status} =
        evaluate_config(
          unquote(apps),
          Map.delete(unquote(Macro.escape(environment)), unquote(variable))
        )

      assert status != 0
      assert output =~ "environment variable #{unquote(variable)} is missing"
    end
  end

  test "admin Backplane settings remain available outside production" do
    config =
      read_config!(
        @admin_apps,
        %{"BACKPLANE_SERVER_URL" => "http://backplane.test", "BACKPLANE_API_KEY" => "test-key"},
        :test
      )

    assert config[:gsmlg_app_admin][:backplane] ==
             [server_url: "http://backplane.test", auth_token: "test-key"]
  end

  defp read_config!(apps, environment, config_env \\ :prod) do
    {output, status} = evaluate_config(apps, environment, config_env)
    assert status == 0, output
    output |> Base.decode64!() |> :erlang.binary_to_term()
  end

  defp evaluate_config(apps, environment, config_env \\ :prod) do
    script = """
    for app <- #{inspect(apps)} do
      :ok = :application.load({:application, app, [vsn: ~c"1.0.0", modules: [], applications: []]})
    end

    config = Config.Reader.read!(#{inspect(@runtime_path)}, env: #{inspect(config_env)})
    IO.write(Base.encode64(:erlang.term_to_binary(config)))
    """

    cleared_environment =
      Map.new(
        Map.keys(Map.merge(@public_env, @admin_env)) ++
          [
            "BACKPLANE_SERVER_URL",
            "BACKPLANE_AUTH_TOKEN",
            "BACKPLANE_API_KEY",
            "PGHOST",
            "POOL_SIZE",
            "ECTO_IPV6"
          ],
        &{&1, nil}
      )

    System.cmd(System.find_executable("elixir"), ["--erl", "+S 2:2", "-e", script],
      env: Map.to_list(Map.merge(cleared_environment, environment)),
      stderr_to_stdout: true
    )
  end
end
