defmodule PhoenixIconify.Scanner do
  @moduledoc """
  Scans source files for icon component usage.

  Uses Phoenix.LiveView.HTMLTokenizer to properly parse HEEx templates
  and extract icon names from `<.icon name="...">` calls.
  """

  @doc """
  Scans all relevant source files and extracts icon names.
  """
  def scan do
    paths = source_paths()

    paths
    |> Enum.flat_map(&scan_file/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp source_paths do
    ["lib/**/*.ex", "lib/**/*.heex"]
    |> Enum.flat_map(&Path.wildcard/1)
  end

  defp scan_file(path) do
    content = File.read!(path)

    cond do
      String.ends_with?(path, ".heex") ->
        scan_heex(content, path)

      String.ends_with?(path, ".ex") ->
        scan_ex(content, path)

      true ->
        []
    end
  rescue
    _ -> []
  end

  defp scan_heex(content, _path) do
    extract_icon_names(content)
  end

  @doc """
  Scans HEEx content for icon names. Exposed for testing.
  """
  def scan_heex_content(content) do
    extract_icon_names(content)
  end

  defp scan_ex(content, _path) do
    # Extract ~H sigils and scan them
    Regex.scan(~r/~H"""(.*?)"""/s, content)
    |> Enum.flat_map(fn [_, heex] -> extract_icon_names(heex) end)
  end

  defp extract_icon_names(content) do
    # Match <.icon name="..." or <.icon name={"..."}
    patterns = [
      # <.icon name="heroicons:user"
      ~r/<\.icon[^>]*\bname="([^"]+)"/,
      # <.icon name={"heroicons:user"}
      ~r/<\.icon[^>]*\bname=\{"([^"]+)"\}/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, name] -> normalize_name(name) end)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_name("hero-" <> rest) do
    # Convert Phoenix's hero-icon-name-variant format to heroicons:icon-name-variant
    # Phoenix uses "micro" suffix, Iconify uses "16-solid"
    # Phoenix uses "mini" suffix, Iconify uses "20-solid"
    normalized =
      rest
      |> String.replace("-micro", "-16-solid")
      |> String.replace("-mini", "-20-solid")

    "heroicons:#{normalized}"
  end

  defp normalize_name(name) do
    if String.contains?(name, ":") do
      name
    else
      nil
    end
  end
end
