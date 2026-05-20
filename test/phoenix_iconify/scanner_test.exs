defmodule PhoenixIconify.ScannerTest do
  use ExUnit.Case, async: true

  alias PhoenixIconify.Scanner

  describe "scan_heex_content/1" do
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
end
