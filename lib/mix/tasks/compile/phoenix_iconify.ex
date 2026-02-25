defmodule Mix.Tasks.Compile.PhoenixIconify do
  @moduledoc """
  Compiles icon assets by discovering icons used in templates.

  This compiler:
  1. Scans compiled modules for icon component calls
  2. Extracts literal icon names from the `name` attribute
  3. Fetches missing icons from Iconify
  4. Updates the manifest in priv/iconify/

  ## Usage

  Add to your mix.exs:

      def project do
        [
          compilers: Mix.compilers() ++ [:phoenix_iconify],
          # ...
        ]
      end

  """

  use Mix.Task.Compiler

  alias PhoenixIconify.{Cache, Manifest, Scanner}

  @recursive true

  @impl true
  def run(_args) do
    # Ensure Finch is started for HTTP requests
    {:ok, _} = Application.ensure_all_started(:req)

    # Scan source files for icon usage
    scanned_icons = Scanner.scan()

    # Add extra icons from config (for dynamic usage)
    extra_icons =
      Application.get_env(:phoenix_iconify, :extra_icons, [])
      |> Enum.map(&PhoenixIconify.normalize_name/1)
      |> Enum.reject(&is_nil/1)

    icons = Enum.uniq(scanned_icons ++ extra_icons) |> Enum.sort()

    if icons == [] do
      {:ok, []}
    else
      process_icons(icons)
    end
  end

  defp process_icons(icon_names) do
    # Validate icon names
    {valid, invalid} =
      Enum.split_with(icon_names, fn name ->
        case Iconify.parse_name(name) do
          {:ok, _, _} -> true
          :error -> false
        end
      end)

    # Warn about invalid icon names
    for name <- invalid do
      Mix.shell().error(
        "PhoenixIconify: Invalid icon name format: #{inspect(name)}. " <>
          "Expected format: \"prefix:icon-name\" (e.g., \"heroicons:user\")"
      )
    end

    # Read existing manifest
    manifest = Manifest.read()

    # Find icons we don't have yet
    missing =
      valid
      |> Enum.reject(&Map.has_key?(manifest, &1))

    if missing == [] do
      # All icons already cached
      {:ok, []}
    else
      # Fetch missing icons
      Mix.shell().info("PhoenixIconify: Fetching #{length(missing)} icon(s)...")

      fetched = fetch_icons(missing)

      # Update manifest
      updated = Map.merge(manifest, fetched)
      Manifest.write(updated)

      # Clear the persistent_term cache so it reloads
      Manifest.clear_cache()

      fetched_count = map_size(fetched)
      failed_count = length(missing) - fetched_count

      if failed_count > 0 do
        Mix.shell().info("PhoenixIconify: Fetched #{fetched_count}, failed #{failed_count}")
      else
        Mix.shell().info("PhoenixIconify: Fetched #{fetched_count} icon(s)")
      end

      {:ok, []}
    end
  end

  defp fetch_icons(icon_names) do
    # Group by prefix for efficient fetching
    results =
      icon_names
      |> Enum.group_by(fn name ->
        case Iconify.parse_name(name) do
          {:ok, prefix, _icon_name} -> prefix
          :error -> nil
        end
      end)
      |> Enum.reject(fn {prefix, _} -> is_nil(prefix) end)
      |> Enum.flat_map(fn {prefix, names} ->
        fetch_prefix_icons(prefix, names)
      end)

    # Warn about icons that couldn't be fetched
    fetched_names = Enum.map(results, fn {name, _} -> name end)
    not_found = icon_names -- fetched_names

    for name <- not_found do
      Mix.shell().error("PhoenixIconify: Icon not found: #{name}")
    end

    Map.new(results)
  end

  defp fetch_prefix_icons(prefix, full_names) do
    # Extract just the icon names (without prefix)
    icon_names =
      full_names
      |> Enum.map(fn name ->
        {:ok, _prefix, icon_name} = Iconify.parse_name(name)
        icon_name
      end)

    # Try to get icons from cache first
    case Cache.fetch_set(prefix) do
      {:ok, set} ->
        # Get icons from cached set
        Enum.flat_map(icon_names, fn icon_name ->
          case Iconify.Set.get(set, icon_name) do
            {:ok, icon} ->
              full_name = "#{prefix}:#{icon_name}"
              data = %{body: icon.body, viewbox: Iconify.Icon.viewbox(icon)}
              [{full_name, data}]

            :error ->
              []
          end
        end)

      {:error, _} ->
        # Fall back to API for individual icons
        fetch_icons_from_api(prefix, icon_names)
    end
  end

  defp fetch_icons_from_api(prefix, icon_names) do
    case Iconify.Fetcher.fetch_icons(prefix, icon_names) do
      {:ok, icons} ->
        Enum.map(icons, fn {name, icon} ->
          full_name = "#{prefix}:#{name}"
          data = %{body: icon.body, viewbox: Iconify.Icon.viewbox(icon)}
          {full_name, data}
        end)

      {:error, reason} ->
        Mix.shell().error("PhoenixIconify: Failed to fetch #{prefix} icons: #{inspect(reason)}")
        []
    end
  end
end
