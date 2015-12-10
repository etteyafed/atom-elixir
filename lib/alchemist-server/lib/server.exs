Code.require_file "api/comp.exs", __DIR__
Code.require_file "api/docl.exs", __DIR__
Code.require_file "api/defl.exs", __DIR__
Code.require_file "api/eval.exs", __DIR__
Code.require_file "api/info.exs", __DIR__

defmodule Alchemist.Server do

  @version "0.1.0-beta"

  @moduledoc """
  The Alchemist-Server operates as an informant for a specific desired
  Elixir Mix project and serves with informations as the following:

    * Completion for Modules and functions.
    * Documentation lookup for Modules and functions.
    * Code evaluation and quoted representation of code.
    * Definition lookup of code.
    * Listing of all available Mix tasks.
    * Listing of all available Modules with documentation.
  """

  alias Alchemist.API

  def start([env]) do
    loop(all_loaded(), env)
  end

  def loop(loaded, env) do
    line  = IO.gets("") |> String.rstrip()
    paths = load_paths(env)
    apps  = load_apps(env)

    try do
      read_input(line)
    rescue
      e ->
        IO.puts(:stderr, "Server Error: \n" <> Exception.message(e) <> "\n" <> Exception.format_stacktrace(System.stacktrace))
    end

    purge_modules(loaded)
    purge_paths(paths)
    purge_apps(apps)

    loop(loaded, env)
  end

  def read_input(line) do
    case line |> String.split(" ", parts: 2) do
      ["COMP", args] ->
        API.Comp.request(args)
      ["DOCL", args] ->
        API.Docl.request(args)
      ["INFO", args] ->
        API.Info.request(args)
      ["EVAL", args] ->
        API.Eval.request(args)
      ["DEFL", args] ->
        API.Defl.request(args)
      _ ->
        nil
    end
  end

  defp all_loaded() do
    for {m,_} <- :code.all_loaded, do: m
  end

  defp load_paths(env) do
    for path <- Path.wildcard("_build/#{env}/lib/*/ebin") do
      Code.prepend_path(path)
      path
    end
  end

  defp load_apps(env) do
    for path <- Path.wildcard("_build/#{env}/lib/*/ebin/*.app") do
      app = path |> Path.basename() |> Path.rootname() |> String.to_atom
      Application.load(app)
      app
    end
  end

  defp purge_modules(loaded) do
    for m <- (all_loaded() -- loaded) do
      :code.delete(m)
      :code.purge(m)
    end
  end

  defp purge_paths(paths) do
    for p <- paths, do: Code.delete_path(p)
  end

  defp purge_apps(apps) do
    for a <- apps, do: Application.unload(a)
  end
end