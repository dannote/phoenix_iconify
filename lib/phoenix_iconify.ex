defmodule PhoenixIconify do
  @moduledoc """
  Phoenix components for Iconify icons with compile-time discovery.
  """

  use Phoenix.Component
  require Logger

  alias Phoenix.HTML

  @doc """
  Renders an icon as an inline SVG.

  ## Examples

      <.icon name="lucide:settings" class="size-5" />
      <.icon name="hero-user" class="size-6 text-zinc-500" />
      <.icon name="mdi:account" label="Account" />
      <.icon name="lucide:x" phx-click="close" />

  """
  attr(:name, :string, required: true, doc: "Icon name (for example, lucide:settings)")
  attr(:class, :string, default: nil, doc: "CSS classes")
  attr(:label, :string, default: nil, doc: "Accessible label. Makes the SVG role=img.")
  attr(:title, :string, default: nil, doc: "Optional SVG title text")
  attr(:size, :any, default: nil, doc: "Width and height to apply together")
  attr(:width, :any, default: nil, doc: "SVG width attribute")
  attr(:height, :any, default: nil, doc: "SVG height attribute")
  attr(:rotate, :integer, default: 0, doc: "Additional 90-degree rotations")
  attr(:flip, :string, default: nil, doc: "Flip direction: horizontal, vertical, or both")
  attr(:h_flip, :boolean, default: false, doc: "Apply horizontal flip")
  attr(:v_flip, :boolean, default: false, doc: "Apply vertical flip")
  attr(:rest, :global, doc: "Additional SVG attributes")

  def icon(assigns) do
    icon_data = get_icon(assigns.name)
    render_data = render_data(icon_data, assigns)
    svg_attrs = svg_attrs(assigns, render_data)

    assigns =
      assigns
      |> assign(:body, render_data.body)
      |> assign(:svg_attrs, svg_attrs)

    ~H"""
    <svg {@svg_attrs}><%= if @title do %><title><%= @title %></title><% end %><%= HTML.raw(@body) %></svg>
    """
  end

  @doc """
  Gets icon data by name.
  """
  def get_icon(name) when is_binary(name) do
    normalized = normalize_name(name)
    icons = PhoenixIconify.Manifest.get_icons()

    case Map.fetch(icons, normalized) do
      {:ok, icon_data} -> icon_data
      :error -> handle_missing_icon(normalized, name)
    end
  end

  def get_icon(nil) do
    maybe_warn("Icon name is nil")
    fallback_icon()
  end

  def get_icon(other) do
    maybe_warn("Invalid icon name: #{inspect(other)}")
    fallback_icon()
  end

  @doc """
  Checks if an icon exists in the manifest.
  """
  def icon_exists?(name) when is_binary(name) do
    normalized = normalize_name(name)
    PhoenixIconify.Manifest.get_icons() |> Map.has_key?(normalized)
  end

  def icon_exists?(_), do: false

  @doc """
  Lists all available icon names from the manifest.
  """
  def list_icons do
    PhoenixIconify.Manifest.get_icons() |> Map.keys() |> Enum.sort()
  end

  @doc """
  Normalizes icon names to the canonical Iconify format.
  """
  def normalize_name("hero-" <> rest) do
    normalized =
      rest
      |> String.replace_suffix("-micro", "-16-solid")
      |> String.replace_suffix("-mini", "-20-solid")

    "heroicons:#{normalized}"
  end

  def normalize_name(name) when is_binary(name), do: name
  def normalize_name(_), do: nil

  defp render_data(%Iconify.Icon{} = icon, assigns) do
    {h_flip, v_flip} = flip_options(assigns.flip, assigns.h_flip, assigns.v_flip)

    {body, viewbox} =
      Iconify.SVG.build_body(icon, rotate: assigns.rotate, h_flip: h_flip, v_flip: v_flip)

    %{body: body, viewbox: viewbox}
  end

  defp flip_options(flip, h_flip, v_flip) do
    flip = to_string(flip || "")

    {
      h_flip or String.contains?(flip, "horizontal") or String.contains?(flip, "both"),
      v_flip or String.contains?(flip, "vertical") or String.contains?(flip, "both")
    }
  end

  defp svg_attrs(assigns, render_data) do
    base = %{
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: render_data.viewbox,
      fill: "currentColor",
      class: assigns.class
    }

    base
    |> maybe_put(:width, assigns.width || assigns.size)
    |> maybe_put(:height, assigns.height || assigns.size)
    |> Map.merge(accessibility_attrs(assigns))
    |> Map.merge(assigns.rest)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp accessibility_attrs(%{label: label, title: title})
       when is_binary(label) or is_binary(title) do
    %{
      role: "img",
      "aria-label": label || title
    }
  end

  defp accessibility_attrs(_assigns), do: %{"aria-hidden": "true"}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp handle_missing_icon(normalized, original) do
    maybe_warn(missing_icon_message(normalized, original))

    if runtime_fetch_enabled?() do
      fetch_icon_at_runtime(normalized)
    else
      fallback_icon()
    end
  end

  defp missing_icon_message(normalized, original) do
    suffix = if normalized != original, do: " (from #{original})", else: ""

    "Icon not found: #{normalized}#{suffix}. " <>
      "If this icon name is dynamic, add it to config :phoenix_iconify, extra_icons: [#{inspect(normalized)}] and run mix compile."
  end

  defp fetch_icon_at_runtime(name) do
    case Iconify.parse_name(name) do
      {:ok, prefix, icon_name} ->
        case Iconify.Fetcher.fetch_icon(prefix, icon_name) do
          {:ok, icon} ->
            icon = %{icon | name: name}
            PhoenixIconify.Manifest.add_icon(name, icon)
            icon

          {:error, _} ->
            fallback_icon()
        end

      :error ->
        fallback_icon()
    end
  rescue
    _ -> fallback_icon()
  end

  defp maybe_warn(message) do
    if Application.get_env(:phoenix_iconify, :warn_on_missing, true) do
      Logger.warning("[PhoenixIconify] #{message}")
    end
  end

  defp runtime_fetch_enabled? do
    Application.get_env(:phoenix_iconify, :runtime_fetch, false)
  end

  defp fallback_icon do
    case Application.get_env(:phoenix_iconify, :fallback) do
      nil ->
        default_fallback_icon()

      fallback_name ->
        icons = PhoenixIconify.Manifest.get_icons()
        Map.get(icons, normalize_name(fallback_name), default_fallback_icon())
    end
  end

  defp default_fallback_icon do
    %Iconify.Icon{
      name: "heroicons:question-mark-circle",
      body:
        ~S(<path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm11.378-3.917c-.89-.777-2.366-.777-3.255 0a.75.75 0 01-.988-1.129c1.454-1.272 3.776-1.272 5.23 0 1.513 1.324 1.513 3.518 0 4.842a3.75 3.75 0 01-.837.552c-.676.328-1.028.774-1.028 1.152v.75a.75.75 0 01-1.5 0v-.75c0-1.279 1.06-2.107 1.875-2.502.182-.088.351-.199.503-.331.83-.727.83-1.857 0-2.584zM12 18a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd" />),
      width: 24,
      height: 24
    }
  end
end
