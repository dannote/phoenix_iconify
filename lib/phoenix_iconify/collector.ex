defmodule PhoenixIconify.Collector do
  @moduledoc """
  Collects icon names from compiled modules.

  Extracts icon names from `__components_calls__` module attribute
  that Phoenix's HEEx compiler populates.
  """

  @doc """
  Collects all icon names used in the application.

  Scans all compiled modules for component calls to the icon component
  and extracts literal icon names.
  """
  def collect do
    get_compiled_modules()
    |> Enum.flat_map(&extract_icons_from_module/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp get_compiled_modules do
    app = Mix.Project.config()[:app]

    case :application.get_key(app, :modules) do
      {:ok, modules} -> modules
      _ -> []
    end
  end

  defp extract_icons_from_module(module) do
    if function_exported?(module, :__components_calls__, 0) do
      module.__components_calls__()
      |> Enum.flat_map(&extract_icon_name/1)
    else
      []
    end
  rescue
    _ -> []
  end

  defp extract_icon_name(%{component: component, props: props}) do
    if icon_component?(component) do
      extract_name_from_props(props)
    else
      []
    end
  end

  defp extract_icon_name(_), do: []

  defp icon_component?({PhoenixIconify, :icon}), do: true
  defp icon_component?({_module, :icon}), do: true
  defp icon_component?(_), do: false

  defp extract_name_from_props(props) when is_list(props) do
    Enum.find_value(props, [], fn
      %{name: :name, value: value} -> extract_string_value(value)
      _ -> nil
    end)
  end

  defp extract_name_from_props(_), do: []

  defp extract_string_value({:string, value, _meta}) when is_binary(value), do: [normalize_name(value)]
  defp extract_string_value(value) when is_binary(value), do: [normalize_name(value)]
  defp extract_string_value(_), do: []

  defp normalize_name("hero-" <> rest), do: "heroicons:#{rest}"
  defp normalize_name(name), do: name
end
