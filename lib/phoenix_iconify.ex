defmodule PhoenixIconify do
  @moduledoc """
  Phoenix components for Iconify icons with compile-time discovery.

  ## Usage

  1. Add the compiler to your `mix.exs`:

      ```elixir
      def project do
        [
          compilers: Mix.compilers() ++ [:phoenix_iconify],
          # ...
        ]
      end
      ```

  2. Import the component in your web module:

      ```elixir
      defp html_helpers do
        quote do
          import PhoenixIconify, only: [icon: 1]
          # ...
        end
      end
      ```

  3. Use icons in your templates:

      ```heex
      <.icon name="heroicons:user" class="w-5 h-5" />
      <.icon name="lucide:home" />
      ```

  Icons are automatically discovered at compile time, fetched from Iconify,
  and embedded into your application.

  ## Dynamic Icons

  For dynamic icon names (e.g., `<.icon name={@icon} />`), icons cannot be
  discovered at compile time. You have two options:

  1. **Pre-register icons** - Add them to your config:

      ```elixir
      config :phoenix_iconify,
        extra_icons: ["heroicons:check", "heroicons:x-mark"]
      ```

  2. **Runtime fetching** (dev only) - Enable runtime fetching for development:

      ```elixir
      config :phoenix_iconify,
        runtime_fetch: true  # Only for dev!
      ```

  ## Configuration

      config :phoenix_iconify,
        # Icon to show when requested icon is not found
        fallback: "heroicons:question-mark-circle",

        # Additional icons to include (for dynamic usage)
        extra_icons: [],

        # Enable runtime fetching (dev only, requires :req)
        runtime_fetch: false,

        # Log warnings when icons are not found
        warn_on_missing: true

  """

  use Phoenix.Component
  require Logger

  @doc """
  Renders an icon as an inline SVG.

  ## Attributes

    * `name` - Icon name in format "prefix:icon-name" (e.g., "heroicons:user")
              Also supports Phoenix's "hero-*" format for compatibility.
    * `class` - CSS classes to apply to the SVG element
    * All other attributes are passed through to the SVG element

  ## Examples

      <.icon name="heroicons:user" />
      <.icon name="heroicons:user" class="w-6 h-6 text-blue-500" />
      <.icon name="lucide:home" id="home-icon" />

      <%!-- Phoenix hero- format also works --%>
      <.icon name="hero-user" />
      <.icon name="hero-user-solid" />

  """
  attr(:name, :string, required: true, doc: "Icon name (e.g., \"heroicons:user\")")
  attr(:class, :string, default: nil, doc: "CSS classes")
  attr(:rest, :global, doc: "Additional SVG attributes")

  def icon(assigns) do
    icon_data = get_icon(assigns.name)
    assigns = assign(assigns, :icon_data, icon_data)

    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox={@icon_data.viewbox}
      fill="currentColor"
      aria-hidden="true"
      class={@class}
      {@rest}
    ><%= Phoenix.HTML.raw(@icon_data.body) %></svg>
    """
  end

  @doc """
  Gets icon data by name.

  Returns the icon data map with `:body` and `:viewbox` keys.
  Falls back to the configured fallback icon if not found.
  """
  def get_icon(name) when is_binary(name) do
    normalized = normalize_name(name)
    icons = PhoenixIconify.Manifest.get_icons()

    case Map.fetch(icons, normalized) do
      {:ok, icon_data} ->
        icon_data

      :error ->
        handle_missing_icon(normalized, name)
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
    icons = PhoenixIconify.Manifest.get_icons()
    Map.has_key?(icons, normalized)
  end

  def icon_exists?(_), do: false

  @doc """
  Lists all available icon names from the manifest.
  """
  def list_icons do
    PhoenixIconify.Manifest.get_icons() |> Map.keys() |> Enum.sort()
  end

  @doc """
  Normalizes icon names to the canonical format.

  Converts Phoenix's `hero-*` format to `heroicons:*` and handles
  suffix mappings (micro -> 16-solid, mini -> 20-solid).
  """
  def normalize_name("hero-" <> rest) do
    normalized =
      rest
      |> String.replace("-micro", "-16-solid")
      |> String.replace("-mini", "-20-solid")

    "heroicons:#{normalized}"
  end

  def normalize_name(name) when is_binary(name), do: name
  def normalize_name(_), do: nil

  # Private functions

  defp handle_missing_icon(normalized, original) do
    maybe_warn(
      "Icon not found: #{normalized}" <>
        if(normalized != original, do: " (from #{original})", else: "")
    )

    if runtime_fetch_enabled?() do
      fetch_icon_at_runtime(normalized)
    else
      fallback_icon()
    end
  end

  defp fetch_icon_at_runtime(name) do
    case Iconify.parse_name(name) do
      {:ok, prefix, icon_name} ->
        case Iconify.Fetcher.fetch_icon(prefix, icon_name) do
          {:ok, icon} ->
            icon_data = %{body: icon.body, viewbox: Iconify.Icon.viewbox(icon)}
            # Cache it for future requests
            PhoenixIconify.Manifest.add_icon(name, icon_data)
            icon_data

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
    # Question mark circle from heroicons (hardcoded to avoid circular dependency)
    %{
      body:
        ~S(<path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm11.378-3.917c-.89-.777-2.366-.777-3.255 0a.75.75 0 01-.988-1.129c1.454-1.272 3.776-1.272 5.23 0 1.513 1.324 1.513 3.518 0 4.842a3.75 3.75 0 01-.837.552c-.676.328-1.028.774-1.028 1.152v.75a.75.75 0 01-1.5 0v-.75c0-1.279 1.06-2.107 1.875-2.502.182-.088.351-.199.503-.331.83-.727.83-1.857 0-2.584zM12 18a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd" />),
      viewbox: "0 0 24 24"
    }
  end
end
