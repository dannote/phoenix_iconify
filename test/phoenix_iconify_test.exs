defmodule PhoenixIconifyTest do
  use ExUnit.Case, async: true

  alias PhoenixIconify.{Manifest, Scanner}

  describe "Manifest" do
    test "read/write round trip" do
      path = Path.join(System.tmp_dir!(), "test_manifest_#{:rand.uniform(1_000_000)}.etf")

      try do
        icons = %{
          "heroicons:user" => %{body: "<path/>", viewbox: "0 0 24 24"},
          "lucide:home" => %{body: "<path/>", viewbox: "0 0 24 24"}
        }

        Manifest.write(icons, path)
        assert Manifest.read(path) == icons
      after
        File.rm(path)
      end
    end

    test "read returns empty map for missing file" do
      assert Manifest.read("/nonexistent/path.etf") == %{}
    end
  end

  describe "Scanner" do
    test "extracts icon names from heex content" do
      content = """
      <.icon name="heroicons:user" class="w-6" />
      <.icon name="lucide:home" />
      <.icon name={"mdi:account"} />
      """

      icons = Scanner.scan_heex_content(content)
      assert "heroicons:user" in icons
      assert "lucide:home" in icons
      assert "mdi:account" in icons
    end

    test "normalizes hero- prefix to heroicons:" do
      content = ~s(<.icon name="hero-user" />)
      icons = Scanner.scan_heex_content(content)
      assert "heroicons:user" in icons
    end

    test "converts micro suffix to 16-solid" do
      content = ~s(<.icon name="hero-sun-micro" />)
      icons = Scanner.scan_heex_content(content)
      assert "heroicons:sun-16-solid" in icons
    end

    test "converts mini suffix to 20-solid" do
      content = ~s(<.icon name="hero-sun-mini" />)
      icons = Scanner.scan_heex_content(content)
      assert "heroicons:sun-20-solid" in icons
    end

    test "ignores icons without prefix:name format" do
      content = ~s(<.icon name="just-a-name" />)
      icons = Scanner.scan_heex_content(content)
      assert icons == []
    end
  end

  describe "PhoenixIconify" do
    test "normalize_name/1 handles hero- prefix" do
      assert PhoenixIconify.normalize_name("hero-user") == "heroicons:user"
      assert PhoenixIconify.normalize_name("hero-arrow-left") == "heroicons:arrow-left"
    end

    test "normalize_name/1 converts micro to 16-solid" do
      assert PhoenixIconify.normalize_name("hero-sun-micro") == "heroicons:sun-16-solid"
    end

    test "normalize_name/1 converts mini to 20-solid" do
      assert PhoenixIconify.normalize_name("hero-sun-mini") == "heroicons:sun-20-solid"
    end

    test "normalize_name/1 passes through standard format" do
      assert PhoenixIconify.normalize_name("heroicons:user") == "heroicons:user"
      assert PhoenixIconify.normalize_name("lucide:home") == "lucide:home"
    end

    test "normalize_name/1 returns nil for non-strings" do
      assert PhoenixIconify.normalize_name(nil) == nil
      assert PhoenixIconify.normalize_name(123) == nil
    end

    test "icon_exists?/1 returns false for missing icons" do
      refute PhoenixIconify.icon_exists?("nonexistent:icon")
    end

    test "get_icon/1 returns fallback for nil" do
      icon = PhoenixIconify.get_icon(nil)
      assert is_map(icon)
      assert Map.has_key?(icon, :body)
      assert Map.has_key?(icon, :viewbox)
    end

    test "list_icons/0 returns sorted list" do
      icons = PhoenixIconify.list_icons()
      assert is_list(icons)
      assert icons == Enum.sort(icons)
    end
  end

  describe "Cache" do
    alias PhoenixIconify.Cache

    test "set_path/1 returns correct path" do
      path = Cache.set_path("heroicons")
      assert String.ends_with?(path, "heroicons.json")
    end

    test "has_set?/1 returns false for non-existent set" do
      refute Cache.has_set?("nonexistent-set-12345")
    end

    test "list_cached_sets/0 returns list" do
      sets = Cache.list_cached_sets()
      assert is_list(sets)
    end

    test "stats/0 returns map with expected keys" do
      stats = Cache.stats()
      assert Map.has_key?(stats, :sets)
      assert Map.has_key?(stats, :total_size)
      assert Map.has_key?(stats, :total_size_human)
    end
  end
end
