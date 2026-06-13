defmodule Certitudo.Report.Store do
  @moduledoc """
  Report snapshot lookup and module-query helpers.
  """

  @spec snapshot_path!(keyword()) :: binary()
  def snapshot_path!(opts) when is_list(opts) do
    cond do
      is_binary(opts[:snapshot]) ->
        opts[:snapshot]

      is_binary(opts[:run]) ->
        Path.join([
          Certitudo.Coverage.certitudo_dir(),
          opts[:run],
          "snapshot.json"
        ])

      true ->
        latest_snapshot_path!()
    end
  end

  @spec latest_snapshot_path!() :: binary()
  def latest_snapshot_path! do
    path =
      Certitudo.Coverage.certitudo_dir()
      |> File.ls!()
      |> Enum.map(&Path.join([Certitudo.Coverage.certitudo_dir(), &1]))
      |> Enum.filter(&(File.dir?(&1) and report_dir?(&1)))
      |> Enum.map(&Path.join(&1, "snapshot.json"))
      |> case do
        [] -> nil
        paths -> Enum.max_by(paths, fn path -> File.stat!(path).mtime end)
      end

    if is_binary(path),
      do: path,
      else: Mix.raise("no report snapshot found under .certitudo/")
  end

  @spec read_snapshot!(binary()) :: map()
  def read_snapshot!(path) when is_binary(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  @spec find_module(map(), binary()) ::
          {:ok, binary()} | {:error, :not_found | {:ambiguous, [binary()]}}
  def find_module(modules, query)
      when is_map(modules) and is_binary(query) do
    normalized =
      if String.starts_with?(query, "Elixir."),
        do: query,
        else: "Elixir." <> query

    if Map.has_key?(modules, normalized) do
      {:ok, normalized}
    else
      modules
      |> Map.keys()
      |> Enum.filter(&String.contains?(&1, query))
      |> case do
        [single] -> {:ok, single}
        [] -> {:error, :not_found}
        many -> {:error, {:ambiguous, many}}
      end
    end
  end

  @spec demodulize(binary()) :: binary()
  def demodulize(name) when is_binary(name) do
    String.trim_leading(name, "Elixir.")
  end

  @spec report_lookup_error(binary(), {:ambiguous, [binary()]} | :not_found) ::
          no_return()
  def report_lookup_error(query, {:ambiguous, matches}) do
    Mix.shell().error("error: query is ambiguous: #{query}")

    Enum.each(matches, fn match ->
      Mix.shell().error("  - #{demodulize(match)}")
    end)

    Mix.shell().error("Use full module name to disambiguate.")
    System.halt(1)
  end

  def report_lookup_error(query, :not_found) do
    Mix.shell().error("error: module not found for query: #{query}")
    System.halt(1)
  end

  @spec report_dir?(binary()) :: boolean()
  def report_dir?(dir) do
    File.regular?(Path.join(dir, "snapshot.json")) and
      File.regular?(Path.join(dir, "coverage.coverdata"))
  end
end
