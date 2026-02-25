# PhoenixIconify

Phoenix components for [Iconify](https://iconify.design) icons with compile-time discovery.

Access 200,000+ icons from 150+ icon sets. Browse available icons at [icon-sets.iconify.design](https://icon-sets.iconify.design).

## Features

- **Compile-time discovery** - Icons are automatically detected from your templates
- **On-demand fetching** - Only icons you use are downloaded
- **Zero runtime overhead** - Icons are embedded at compile time
- **LiveView optimized** - Minimal diffs, only attributes change

## Installation

Add `phoenix_iconify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_iconify, "~> 0.1.0"}
  ]
end
```

Add the compiler to your project:

```elixir
def project do
  [
    compilers: Mix.compilers() ++ [:phoenix_iconify],
    # ...
  ]
end
```

## Usage

Import the component in your web module (`lib/my_app_web.ex`):

```elixir
defp html_helpers do
  quote do
    import PhoenixIconify, only: [icon: 1]
    # ...
  end
end
```

Use icons in your templates:

```heex
<.icon name="heroicons:user" />
<.icon name="heroicons:user" class="w-6 h-6 text-blue-500" />
<.icon name="lucide:home" id="home-icon" />
```

## How It Works

1. You use `<.icon name="heroicons:user" />` in your templates
2. During compilation, the compiler scans for icon component calls
3. It extracts literal icon names from the `name` attribute
4. Missing icons are fetched from the Iconify API
5. Icons are cached in `priv/iconify/manifest.etf`
6. At runtime, icons are loaded from the manifest

## Icon Names

Icons use the format `prefix:icon-name`:

- `heroicons:user` - Heroicons user icon
- `heroicons:user-solid` - Heroicons solid user
- `lucide:home` - Lucide home icon
- `mdi:account` - Material Design Icons account

Browse all icons at [icon-sets.iconify.design](https://icon-sets.iconify.design).

## Configuration

```elixir
# config/config.exs
config :phoenix_iconify,
  # Pre-register icons for dynamic usage (e.g., icons from database)
  extra_icons: ["heroicons:check", "heroicons:x-mark"],
  
  # Fallback icon when requested icon is not found
  fallback: "heroicons:question-mark-circle",
  
  # Log warnings when icons are not found (default: true)
  warn_on_missing: true
```

## Caching

Icon sets are cached locally in `priv/iconify/sets/` to avoid repeated downloads.

```bash
# Pre-fetch icon sets for faster subsequent compiles
mix phoenix_iconify.cache fetch

# List cached sets
mix phoenix_iconify.cache list

# Clear cache
mix phoenix_iconify.cache clear

# Show statistics
mix phoenix_iconify.stats
```

## Dynamic Icons

For icons that can't be discovered at compile time (e.g., from database):

```elixir
config :phoenix_iconify,
  extra_icons: [
    "heroicons:check",
    "heroicons:x-mark",
    "heroicons:exclamation-triangle"
  ]
```

## Mix Tasks

```bash
mix phoenix_iconify           # Show help
mix phoenix_iconify.stats     # Show statistics
mix phoenix_iconify.list      # List icons in manifest
mix phoenix_iconify.cache     # Cache management
```

## License

MIT
