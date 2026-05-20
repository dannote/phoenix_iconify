defmodule PhoenixIconify.CacheTest do
  use ExUnit.Case, async: true

  alias PhoenixIconify.Cache

  describe "paths" do
    test "set_path/1 returns set cache path" do
      path = Cache.set_path("heroicons")
      assert String.ends_with?(path, "heroicons.json")
    end
  end

  describe "cache checks" do
    test "has_set?/1 returns false for non-existent set" do
      refute Cache.has_set?("nonexistent-set-12345")
    end

    test "list_cached_sets/0 returns list" do
      assert is_list(Cache.list_cached_sets())
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      stats = Cache.stats()
      assert Map.has_key?(stats, :sets)
      assert Map.has_key?(stats, :total_size)
      assert Map.has_key?(stats, :total_size_human)
    end
  end
end
