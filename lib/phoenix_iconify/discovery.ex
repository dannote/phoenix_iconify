defmodule PhoenixIconify.Discovery do
  @moduledoc false

  alias PhoenixIconify.Scanner

  def icons do
    (Scanner.scan() ++ extra_icons())
    |> Enum.uniq()
    |> Enum.sort()
  end

  def split_valid(icon_names) do
    Enum.split_with(icon_names, &valid?/1)
  end

  defp extra_icons do
    :phoenix_iconify
    |> Application.get_env(:extra_icons, [])
    |> Enum.map(&PhoenixIconify.normalize_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp valid?(name), do: match?({:ok, _, _}, Iconify.parse_name(name))
end
