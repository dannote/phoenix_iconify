defmodule Mix.Tasks.PhoenixIconify do
  @shortdoc "Manage PhoenixIconify icons and cache"
  @moduledoc """
  Tasks for managing PhoenixIconify icons and cache.

  ## Commands

      mix phoenix_iconify           # Show help
      mix phoenix_iconify.stats     # Show icon and cache statistics
      mix phoenix_iconify.list      # List all icons in manifest
      mix phoenix_iconify.cache     # Cache management

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
      |> Map.keys()
      |> Enum.map(fn name ->
        case String.split(name, ":", parts: 2) do
          [prefix, _] -> prefix
          _ -> "unknown"
        end
      end)
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
    |> Enum.map(fn {prefix, count} -> "    - #{prefix}: #{count}" end)
    |> Enum.join("\n")
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

    prefixes_to_fetch =
      if prefixes == [] do
        # Get all prefixes from manifest
        PhoenixIconify.Manifest.read()
        |> Map.keys()
        |> Enum.map(fn name ->
          case String.split(name, ":", parts: 2) do
            [prefix, _] -> prefix
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
      else
        prefixes
      end

    if prefixes_to_fetch == [] do
      Mix.shell().info("No prefixes to fetch. Run 'mix compile' first to discover icons.")
    else
      Mix.shell().info("Fetching #{length(prefixes_to_fetch)} icon set(s)...")

      Enum.each(prefixes_to_fetch, fn prefix ->
        if PhoenixIconify.Cache.has_set?(prefix) do
          Mix.shell().info("  #{prefix}: already cached")
        else
          case PhoenixIconify.Cache.fetch_set(prefix) do
            {:ok, set} ->
              Mix.shell().info("  #{prefix}: fetched (#{Iconify.Set.count(set)} icons)")

            {:error, reason} ->
              Mix.shell().error("  #{prefix}: failed (#{inspect(reason)})")
          end
        end
      end)
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
end
