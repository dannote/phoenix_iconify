defmodule Mix.Tasks.PhoenixIconify do
  @shortdoc "Manage PhoenixIconify icons and cache"
  @moduledoc """
  Tasks for managing PhoenixIconify icons and cache.

  ## Commands

      mix phoenix_iconify           # Show help
      mix phoenix_iconify.stats     # Show icon and cache statistics
      mix phoenix_iconify.list      # List all icons in manifest
      mix phoenix_iconify.cache     # Cache management
      mix phoenix_iconify.prefetch  # Scan and fetch discovered icons
      mix phoenix_iconify.audit     # Report missing discovered icons
      mix phoenix_iconify.clean     # Remove unused manifest icons

  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.shell().info("""
    PhoenixIconify - Iconify icons for Phoenix

    Available commands:

      mix phoenix_iconify.stats     Show icon and cache statistics
      mix phoenix_iconify.list      List all icons in manifest
      mix phoenix_iconify.cache     Cache management (fetch, clear, list)
      mix phoenix_iconify.prefetch  Scan and fetch discovered icons
      mix phoenix_iconify.audit     Report missing discovered icons
      mix phoenix_iconify.clean     Remove unused manifest icons

    For more info on a command:

      mix help phoenix_iconify.<command>
    """)
  end
end

defmodule Mix.Tasks.PhoenixIconify.Stats do
  @shortdoc "Show icon and cache statistics"
  @moduledoc """
  Shows statistics about discovered icons and cached icon sets.

      mix phoenix_iconify.stats

  """

  use Mix.Task

  @impl true
  def run(_args) do
    Application.ensure_all_started(:phoenix_iconify)

    manifest = PhoenixIconify.Manifest.read()
    cache_stats = PhoenixIconify.Cache.stats()

    prefixes =
      manifest
      |> Enum.map(fn {name, _icon} -> prefix_from_icon(name) || "unknown" end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> -count end)

    Mix.shell().info("""

    PhoenixIconify Statistics
    ========================

    Manifest:
      Total icons: #{map_size(manifest)}
      By prefix:
    #{format_prefixes(prefixes)}

    Cache:
      Cached sets: #{cache_stats.sets}
      Total size: #{cache_stats.total_size_human}
    """)
  end

  defp format_prefixes(prefixes) do
    prefixes
    |> Enum.map(fn {prefix, count} -> ["    - ", prefix, ": ", Integer.to_string(count)] end)
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp prefix_from_icon(name) do
    case String.split(name, ":", parts: 2) do
      [prefix, _] -> prefix
      _ -> nil
    end
  end
end

defmodule Mix.Tasks.PhoenixIconify.List do
  @shortdoc "List all icons in manifest"
  @moduledoc """
  Lists all icons currently in the manifest.

      mix phoenix_iconify.list
      mix phoenix_iconify.list --prefix heroicons

  ## Options

    * `--prefix` - Filter by icon prefix

  """

  use Mix.Task

  @impl true
  def run(args) do
    Application.ensure_all_started(:phoenix_iconify)

    {opts, _, _} = OptionParser.parse(args, strict: [prefix: :string])
    prefix_filter = opts[:prefix]

    icons =
      PhoenixIconify.Manifest.read()
      |> Map.keys()
      |> Enum.sort()
      |> maybe_filter_prefix(prefix_filter)

    if icons == [] do
      Mix.shell().info("No icons found in manifest.")
    else
      Mix.shell().info("\nIcons in manifest (#{length(icons)}):\n")

      Enum.each(icons, fn name ->
        Mix.shell().info("  #{name}")
      end)

      Mix.shell().info("")
    end
  end

  defp maybe_filter_prefix(icons, nil), do: icons

  defp maybe_filter_prefix(icons, prefix) do
    Enum.filter(icons, &String.starts_with?(&1, "#{prefix}:"))
  end
end

defmodule Mix.Tasks.PhoenixIconify.Cache do
  @shortdoc "Manage icon set cache"
  @moduledoc """
  Manage the local icon set cache.

      mix phoenix_iconify.cache list      # List cached icon sets
      mix phoenix_iconify.cache fetch     # Fetch icon sets for all manifest icons
      mix phoenix_iconify.cache clear     # Clear the cache

  ## Fetch

  Pre-fetches complete icon sets for all prefixes used in your manifest.
  This speeds up future compilations.

      mix phoenix_iconify.cache fetch
      mix phoenix_iconify.cache fetch heroicons lucide

  ## Clear

  Removes all cached icon sets.

      mix phoenix_iconify.cache clear

  """

  use Mix.Task

  @impl true
  def run(["list" | _]) do
    sets = PhoenixIconify.Cache.list_cached_sets()

    if sets == [] do
      Mix.shell().info("No icon sets cached.")
    else
      Mix.shell().info("\nCached icon sets (#{length(sets)}):\n")
      Enum.each(sets, &Mix.shell().info("  #{&1}"))
      Mix.shell().info("")

      stats = PhoenixIconify.Cache.stats()
      Mix.shell().info("Total size: #{stats.total_size_human}")
    end
  end

  def run(["fetch" | prefixes]) do
    {:ok, _} = Application.ensure_all_started(:req)

    prefixes_to_fetch = prefixes_to_fetch(prefixes)

    if prefixes_to_fetch == [] do
      Mix.shell().info("No prefixes to fetch. Run 'mix compile' first to discover icons.")
    else
      Mix.shell().info("Fetching #{length(prefixes_to_fetch)} icon set(s)...")

      Enum.each(prefixes_to_fetch, &fetch_prefix/1)
    end
  end

  def run(["clear" | _]) do
    PhoenixIconify.Cache.clear()
    Mix.shell().info("Cache cleared.")
  end

  def run(_) do
    Mix.shell().info("""
    Usage:
      mix phoenix_iconify.cache list      List cached icon sets
      mix phoenix_iconify.cache fetch     Fetch icon sets
      mix phoenix_iconify.cache clear     Clear the cache
    """)
  end

  defp prefixes_to_fetch([]) do
    PhoenixIconify.Manifest.read()
    |> Enum.map(fn {name, _icon} -> prefix_from_icon(name) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp prefixes_to_fetch(prefixes), do: prefixes

  defp prefix_from_icon(name) do
    case String.split(name, ":", parts: 2) do
      [prefix, _] -> prefix
      _ -> nil
    end
  end

  defp fetch_prefix(prefix) do
    if PhoenixIconify.Cache.has_set?(prefix) do
      Mix.shell().info("  #{prefix}: already cached")
    else
      report_prefix_fetch(prefix, PhoenixIconify.Cache.fetch_set(prefix))
    end
  end

  defp report_prefix_fetch(prefix, {:ok, set}) do
    Mix.shell().info("  #{prefix}: fetched (#{Iconify.Set.count(set)} icons)")
  end

  defp report_prefix_fetch(prefix, {:error, reason}) do
    Mix.shell().error("  #{prefix}: failed (#{inspect(reason)})")
  end
end

defmodule Mix.Tasks.PhoenixIconify.Prefetch do
  @shortdoc "Scan and fetch discovered icons"
  @moduledoc """
  Scans the project for icon component usage and updates the manifest.

      mix phoenix_iconify.prefetch
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("compile.phoenix_iconify")
  end
end

defmodule Mix.Tasks.PhoenixIconify.Audit do
  @shortdoc "Report missing discovered icons"
  @moduledoc """
  Reports discovered icons that are not present in the manifest.

      mix phoenix_iconify.audit
  """

  use Mix.Task

  @impl true
  def run(_args) do
    manifest = PhoenixIconify.Manifest.read()
    missing = Enum.reject(PhoenixIconify.Discovery.icons(), &Map.has_key?(manifest, &1))

    if missing == [] do
      Mix.shell().info("PhoenixIconify: all discovered icons are present in the manifest.")
    else
      Mix.shell().error("PhoenixIconify: #{length(missing)} missing icon(s):")
      Enum.each(missing, &Mix.shell().error("  #{&1}"))
    end
  end
end

defmodule Mix.Tasks.PhoenixIconify.Clean do
  @shortdoc "Remove unused manifest icons"
  @moduledoc """
  Removes manifest entries that are not currently discovered or configured as extra icons.

      mix phoenix_iconify.clean
  """

  use Mix.Task

  @impl true
  def run(_args) do
    keep = MapSet.new(PhoenixIconify.Discovery.icons())
    manifest = PhoenixIconify.Manifest.read()
    cleaned = Map.take(manifest, MapSet.to_list(keep))
    removed = map_size(manifest) - map_size(cleaned)

    PhoenixIconify.Manifest.write(cleaned)
    PhoenixIconify.Manifest.clear_cache()

    Mix.shell().info("PhoenixIconify: removed #{removed} unused icon(s).")
  end
end
