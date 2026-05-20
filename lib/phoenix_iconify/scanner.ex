defmodule PhoenixIconify.Scanner do
  @moduledoc """
  Scans source files for literal icon component usage.
  """

  alias Phoenix.LiveView.Tokenizer

  @doc """
  Scans all relevant source files and extracts icon names.
  """
  def scan do
    source_paths()
    |> Enum.flat_map(&scan_file/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Scans HEEx content for icon names. Exposed for testing.
  """
  def scan_heex_content(content) do
    content
    |> tokenize_heex("nofile")
    |> icons_from_tokens()
  end

  defp source_paths do
    ["lib/**/*.ex", "lib/**/*.heex"]
    |> Enum.flat_map(&Path.wildcard/1)
  end

  defp scan_file(path) do
    content = File.read!(path)

    cond do
      String.ends_with?(path, ".heex") -> scan_heex(content, path)
      String.ends_with?(path, ".ex") -> scan_ex(content)
      true -> []
    end
  rescue
    _ -> []
  end

  defp scan_heex(content, path) do
    content
    |> tokenize_heex(path)
    |> icons_from_tokens()
  end

  defp scan_ex(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} -> ast |> heex_sigil_sources() |> Enum.flat_map(&scan_heex_content/1)
      {:error, _} -> []
    end
  end

  defp heex_sigil_sources(ast) do
    {_ast, sources} =
      Macro.prewalk(ast, [], fn
        {:sigil_H, _meta, [{:<<>>, _string_meta, [source]}, _modifiers]} = node, sources
        when is_binary(source) ->
          {node, [source | sources]}

        node, sources ->
          {node, sources}
      end)

    Enum.reverse(sources)
  end

  defp tokenize_heex(content, path) do
    state = Tokenizer.init(0, path, content, Phoenix.LiveView.HTMLEngine)

    {tokens, _cont} =
      Tokenizer.tokenize(content, [line: 1, column: 1], [], {:text, :enabled}, state)

    tokens
  end

  defp icons_from_tokens(tokens) do
    tokens
    |> Enum.flat_map(&icon_from_token/1)
    |> Enum.reject(&is_nil/1)
  end

  defp icon_from_token({:local_component, "icon", attrs, _meta}) do
    attrs
    |> Enum.find_value(&name_attr/1)
    |> List.wrap()
  end

  defp icon_from_token(_token), do: []

  defp name_attr({"name", {:string, name, _meta}, _attr_meta}) do
    normalize_name(name)
  end

  defp name_attr({"name", {:expr, expr, _meta}, _attr_meta}) do
    case Code.string_to_quoted(expr) do
      {:ok, name} when is_binary(name) -> normalize_name(name)
      _ -> nil
    end
  end

  defp name_attr(_attr), do: nil

  defp normalize_name("hero-" <> _rest = name), do: PhoenixIconify.normalize_name(name)

  defp normalize_name(name) do
    if String.contains?(name, ":"), do: name
  end
end
