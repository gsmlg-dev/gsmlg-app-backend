defmodule GsmlgAppAdminWeb.PageControllerTest do
  use GsmlgAppAdminWeb.ConnCase

  @password "Password123!"

  setup do
    # Create a test user
    {:ok, user} =
      GsmlgAppAdmin.Accounts.User
      |> Ash.Changeset.for_create(:admin_create, %{
        email: "page_test@example.com",
        password: @password
      })
      |> Ash.create(authorize?: false)

    {:ok, user: user}
  end

  test "GET / redirects to sign-in when not authenticated", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> get(~p"/")

    # Should redirect to sign-in with return_to parameter
    assert redirected_to(conn) =~ "/sign-in"
    assert redirected_to(conn) =~ "return_to"
  end

  test "GET / renders home page when authenticated", %{conn: conn, user: user} do
    # Sign in first
    conn =
      conn
      |> init_test_session(%{})
      |> post("/auth/user/default/sign_in", %{
        "user" => %{
          "email" => to_string(user.email),
          "password" => @password
        }
      })

    # Access home page as authenticated user
    conn = get(recycle(conn), ~p"/")

    assert html_response(conn, 200) =~ "Best in the World!"
  end
end
