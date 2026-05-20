defmodule PhoenixIconifyTest do
  use ExUnit.Case, async: false

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias PhoenixIconify.Manifest

  describe "component" do
    setup do
      Manifest.clear_cache()

      Manifest.add_icon("lucide:settings", %Iconify.Icon{
        name: "lucide:settings",
        body: ~s(<path d="M10 10"/>),
        width: 24,
        height: 24
      })

      on_exit(fn -> Manifest.clear_cache() end)
    end

    test "renders inline svg with class and global attrs" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PhoenixIconify.icon name="lucide:settings" class="size-5" phx-click="open" data-testid="settings" />
        """)

      assert html =~ ~s(<svg)
      assert html =~ ~s(class="size-5")
      assert html =~ ~s(phx-click="open")
      assert html =~ ~s(data-testid="settings")
      assert html =~ ~s(<path d="M10 10"/>)
      assert html =~ ~s(aria-hidden="true")
    end

    test "uses accessible label when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PhoenixIconify.icon name="lucide:settings" label="Settings" />
        """)

      assert html =~ ~s(role="img")
      assert html =~ ~s(aria-label="Settings")
      refute html =~ ~s(aria-hidden="true")
    end

    test "renders title and dimensions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PhoenixIconify.icon name="lucide:settings" title="Settings" size="20" />
        """)

      assert html =~ ~s(<title>Settings</title>)
      assert html =~ ~s(width="20")
      assert html =~ ~s(height="20")
    end
  end

  describe "normalize_name/1" do
    test "handles hero- prefix" do
      assert PhoenixIconify.normalize_name("hero-user") == "heroicons:user"
      assert PhoenixIconify.normalize_name("hero-arrow-left") == "heroicons:arrow-left"
    end

    test "converts micro to 16-solid" do
      assert PhoenixIconify.normalize_name("hero-sun-micro") == "heroicons:sun-16-solid"
    end

    test "converts mini to 20-solid" do
      assert PhoenixIconify.normalize_name("hero-sun-mini") == "heroicons:sun-20-solid"
    end

    test "passes through standard format" do
      assert PhoenixIconify.normalize_name("heroicons:user") == "heroicons:user"
      assert PhoenixIconify.normalize_name("lucide:home") == "lucide:home"
    end

    test "returns nil for non-strings" do
      assert PhoenixIconify.normalize_name(nil) == nil
      assert PhoenixIconify.normalize_name(123) == nil
    end
  end

  describe "icon helpers" do
    test "icon_exists?/1 returns false for missing icons" do
      refute PhoenixIconify.icon_exists?("nonexistent:icon")
    end

    test "get_icon/1 returns fallback for nil" do
      icon = PhoenixIconify.get_icon(nil)
      assert %Iconify.Icon{} = icon
      assert icon.body
    end

    test "list_icons/0 returns sorted list" do
      icons = PhoenixIconify.list_icons()
      assert is_list(icons)
      assert icons == Enum.sort(icons)
    end
  end
end
