defmodule GsmlgAppComponent.AppTest do
  use GsmlgAppComponentTest.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  describe "app_topbar/1" do
    test "renders app topbar with default title" do
      assigns = %{}

      html = render_component(&GsmlgAppComponent.App.app_topbar/1, assigns)

      assert html =~ "GSMLG APP"
      assert html =~ "navbar"
      assert html =~ "bg-primary"
    end

    test "renders app topbar with custom title" do
      assigns = %{title: "Custom App"}

      html = render_component(&GsmlgAppComponent.App.app_topbar/1, assigns)

      assert html =~ "Custom App"
      assert html =~ "navbar"
    end

    test "renders app topbar with custom id and class" do
      assigns = %{id: "custom-topbar", class: "custom-class"}

      html = render_component(&GsmlgAppComponent.App.app_topbar/1, assigns)

      assert html =~ ~s(id="custom-topbar")
      assert html =~ "custom-class"
    end

    test "renders app topbar with user block slot" do
      assigns = %{
        title: "Test App",
        user_block: [%{inner_content: ["<div>User Content</div>"]}]
      }

      html = render_component(&GsmlgAppComponent.App.app_topbar/1, assigns)

      assert html =~ "User Content"
      assert html =~ "dropdown"
    end

    test "includes drawer for mobile navigation" do
      assigns = %{}

      html = render_component(&GsmlgAppComponent.App.app_topbar/1, assigns)

      assert html =~ "app-drawer"
      assert html =~ "drawer-toggle"
      assert html =~ "drawer-button"
    end
  end

  describe "app_menus/1" do
    test "renders empty menus when no menus provided" do
      assigns = %{}

      html = render_component(&GsmlgAppComponent.App.app_menus/1, assigns)

      assert html =~ "menu"
      assert html =~ "rounded-box"
    end

    test "renders menus with menu groups and items" do
      menus = [
        %{
          title: "Main Menu",
          items: [
            %{
              id: "home",
              title: "Home",
              navigate: "/"
            },
            %{
              id: "about",
              title: "About",
              navigate: "/about"
            }
          ]
        },
        %{
          title: "Settings",
          items: [
            %{
              id: "profile",
              title: "Profile",
              navigate: "/profile"
            }
          ]
        }
      ]

      assigns = %{menus: menus}

      html = render_component(&GsmlgAppComponent.App.app_menus/1, assigns)

      assert html =~ "Main Menu"
      assert html =~ "Settings"
      assert html =~ "Home"
      assert html =~ "About"
      assert html =~ "Profile"
      assert html =~ ~s(navigate="/")
      assert html =~ ~s(navigate="/about")
      assert html =~ ~s(navigate="/profile")
    end

    test "highlights active menu item" do
      menus = [
        %{
          title: "Main Menu",
          items: [
            %{
              id: "home",
              title: "Home",
              navigate: "/"
            },
            %{
              id: "about",
              title: "About",
              navigate: "/about"
            }
          ]
        }
      ]

      assigns = %{menus: menus, active_id: "about"}

      html = render_component(&GsmlgAppComponent.App.app_menus/1, assigns)

      assert html =~ ~s(class="active")
      assert html =~ "About"
    end

    test "renders menus with custom id and class" do
      menus = [
        %{
          title: "Test Menu",
          items: [
            %{
              id: "test",
              title: "Test Item",
              navigate: "/test"
            }
          ]
        }
      ]

      assigns = %{menus: menus, id: "custom-menus", class: "custom-menu-class"}

      html = render_component(&GsmlgAppComponent.App.app_menus/1, assigns)

      assert html =~ ~s(id="custom-menus")
      assert html =~ "custom-menu-class"
    end

    test "handles menus without items gracefully" do
      menus = [
        %{
          title: "Empty Menu",
          items: []
        }
      ]

      assigns = %{menus: menus}

      html = render_component(&GsmlgAppComponent.App.app_menus/1, assigns)

      assert html =~ "Empty Menu"
      assert html =~ "menu-title"
    end
  end
end
