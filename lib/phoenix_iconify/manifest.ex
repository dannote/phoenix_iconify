defmodule PhoenixIconify.Manifest do
  @moduledoc """
  Manages the icon manifest stored in priv/.

  The manifest contains all discovered icons, cached between compilations.
  """

  @manifest_filename "manifest.etf"

  @doc """
  Returns the path to the manifest file for the given application.
  """
  def manifest_path(app \\ nil) do
    app = app || Application.get_env(:phoenix_iconify, :otp_app) || Mix.Project.config()[:app]

    priv_dir =
      if app do
        case :code.priv_dir(app) do
          {:error, :bad_name} -> "priv"
          path -> List.to_string(path)
        end
      else
        "priv"
      end

    Path.join([priv_dir, "iconify", @manifest_filename])
  end

  @doc """
  Reads the manifest from disk.
  """
  def read(path \\ nil) do
    path = path || manifest_path()

    if File.exists?(path) do
      path
      |> File.read!()
      |> :erlang.binary_to_term()
    else
      %{}
    end
  end

  @doc """
  Writes the manifest to disk.
  """
  def write(icons, path \\ nil) when is_map(icons) do
    path = path || manifest_path()

    dir = Path.dirname(path)
    File.mkdir_p!(dir)

    binary = :erlang.term_to_binary(icons)
    File.write!(path, binary)

    :ok
  end

  @doc """
  Gets icons from the manifest, loading from the compiled module attribute if available.
  """
  def get_icons do
    case :persistent_term.get({__MODULE__, :icons}, nil) do
      nil ->
        icons = read()
        :persistent_term.put({__MODULE__, :icons}, icons)
        icons

      icons ->
        icons
    end
  end

  @doc """
  Reloads icons from disk into persistent_term.
  """
  def reload do
    icons = read()
    :persistent_term.put({__MODULE__, :icons}, icons)
    icons
  end

  @doc """
  Clears the cached icons.
  """
  def clear_cache do
    :persistent_term.erase({__MODULE__, :icons})
  end

  @doc """
  Adds an icon to the runtime cache and optionally persists to disk.

  This is used for runtime-fetched icons in development.
  """
  def add_icon(name, icon_data, opts \\ []) do
    icons = get_icons()
    updated = Map.put(icons, name, icon_data)
    :persistent_term.put({__MODULE__, :icons}, updated)

    if Keyword.get(opts, :persist, false) do
      write(updated)
    end

    :ok
  end

  @doc """
  Returns the number of icons in the manifest.
  """
  def count do
    get_icons() |> map_size()
  end
end
