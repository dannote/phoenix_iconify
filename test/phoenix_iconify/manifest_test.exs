defmodule PhoenixIconify.ManifestTest do
  use ExUnit.Case, async: true

  alias PhoenixIconify.Manifest

  describe "read/1 and write/2" do
    test "round trips JSON manifests" do
      path = Path.join(System.tmp_dir!(), "test_manifest_#{:rand.uniform(1_000_000)}.json")

      try do
        icons = %{
          "heroicons:user" => %Iconify.Icon{
            name: "heroicons:user",
            body: "<path/>",
            width: 24,
            height: 24
          },
          "lucide:home" => %Iconify.Icon{
            name: "lucide:home",
            body: "<path/>",
            width: 24,
            height: 24
          }
        }

        Manifest.write(icons, path)
        assert Manifest.read(path) == icons
        assert File.read!(path) =~ ~s("version": 1)
        assert File.read!(path) =~ ~s("icons": [)
      after
        File.rm(path)
      end
    end

    test "loads icon atoms before decoding persisted icon fields" do
      path =
        Path.join(System.tmp_dir!(), "test_manifest_strings_#{:rand.uniform(1_000_000)}.json")

      try do
        File.write!(
          path,
          ~s({"version":1,"icons":[{"name":"lucide:sun","body":"<path/>","width":24,"height":24}]})
        )

        assert %{"lucide:sun" => icon} = Manifest.read(path)
        assert icon.width == 24
        assert icon.height == 24
      after
        File.rm(path)
      end
    end

    test "returns empty map for missing file" do
      assert Manifest.read("/nonexistent/path.json") == %{}
    end

    test "raises for invalid manifest" do
      path = Path.join(System.tmp_dir!(), "bad_manifest_#{:rand.uniform(1_000_000)}.json")

      try do
        File.write!(path, ~s({"version":1,"icons":{"bad":"shape"}}))
        assert_raise ArgumentError, fn -> Manifest.read(path) end
      after
        File.rm(path)
      end
    end
  end
end
