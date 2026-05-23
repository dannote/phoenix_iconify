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

    test "finds literal icon strings passed through component attributes" do
      content = ~s(<.nav_item icon="lucide:messages-square">Sessions</.nav_item>)
      icons = Scanner.scan_heex_content(content)
      assert "lucide:messages-square" in icons
    end

    test "recovers same-line icons when the surrounding HEEx cannot be tokenized as a whole" do
      content = ~s(<%= if true do %>\n<.icon name="lucide:circle-check" />\n<% end %>)
      icons = Scanner.scan_heex_content(content)
      assert "lucide:circle-check" in icons
    end

    test "ignores icons without prefix:name format" do
      content = ~s(<.icon name="just-a-name" />)
      icons = Scanner.scan_heex_content(content)
      assert icons == []
    end
  end
end
