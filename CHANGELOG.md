# Changelog

## v0.2.0

- Store discovered icons in a readable JSON manifest
- Render normalized `%Iconify.Icon{}` data directly from the manifest
- Add compile-time discovery through Elixir AST traversal and Phoenix LiveView tokenization
- Add accessibility, sizing, and transformation options to `<.icon />`
- Add `prefetch`, `audit`, and `clean` Mix tasks
- Add CI checks with Credo, Reach smell checks, ExDNA, and tests
- Polish README and package metadata for the `elixir-volt` organization

## v0.1.0

- Initial release
- Phoenix component for rendering icons
- Compile-time icon discovery from `__components_calls__`
- Automatic icon fetching from Iconify API
- Manifest caching in priv/iconify/
