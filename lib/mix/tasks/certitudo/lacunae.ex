defmodule Mix.Tasks.Certitudo.Lacunae do
  @moduledoc """
  Print uncovered executable lines from a coverage snapshot.

  Usage:
    mix certitudo.lacunae
    mix certitudo.lacunae "Certitudo.Coverage"
    mix certitudo.lacunae "Coverage" --run 20260429T141327Z
    mix certitudo.lacunae "Coverage" --snapshot cover/20260429T141327Z/snapshot.json
    mix certitudo.lacunae "Coverage" --force
  """

  use Mix.Task

  alias Certitudo.Report.Store

  @shortdoc "Print uncovered executable lines"

  @impl Mix.Task
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args,
        strict: [run: :string, snapshot: :string, force: :boolean]
      )

    snapshot_path = Store.snapshot_path!(opts)

    selected =
      snapshot_path
      |> snapshot!(opts)
      |> Map.get("modules", %{})
      |> selected_modules(positional)

    Mix.shell().info("snapshot: #{snapshot_path}")

    maybe_warn_stale(snapshot_path, opts)

    selected
    |> Enum.sort_by(fn {name, _data} -> name end)
    |> Enum.each(&print_module/1)
  end

  defp snapshot!(snapshot_path, opts) do
    snapshot = Store.read_snapshot!(snapshot_path)

    if Keyword.get(opts, :force, false) do
      rebuild_snapshot!(snapshot, snapshot_path)
    else
      snapshot
    end
  end

  defp rebuild_snapshot!(snapshot, snapshot_path) do
    coverdata_path = snapshot["run"]["coverdata_path"]
    beam_dirs = fetch_beam_dirs!(snapshot)

    if stale?(snapshot_path) do
      Mix.shell().info(
        "rebuilding snapshot from coverdata: #{coverdata_path}"
      )
    end

    Certitudo.Coverage.create_snapshot_from_coverdata(coverdata_path,
      run_id: snapshot["run"]["id"],
      run_label: snapshot["run"]["label"],
      prefixes: snapshot["filter"]["prefixes"] || [],
      ignore_modules: snapshot["filter"]["ignore_modules"] || [],
      beam_dirs: beam_dirs
    )
  end

  defp fetch_beam_dirs!(%{"run" => %{"beam_dirs" => beam_dirs}})
       when is_list(beam_dirs) do
    beam_dirs
  end

  defp fetch_beam_dirs!(_snapshot) do
    Mix.raise(
      "snapshot does not contain run.beam_dirs; rebuild with --force requires a snapshot created by current certitudo"
    )
  end

  defp maybe_warn_stale(snapshot_path, opts) do
    if not Keyword.get(opts, :force, false) and stale?(snapshot_path) do
      Mix.shell().error(
        "⚠ Snapshot may be stale (beam files changed). Run mix certitudo or use --force."
      )
    end
  end

  defp stale?(snapshot_path) do
    snapshot_mtime = File.stat!(snapshot_path).mtime

    current_beam_paths()
    |> Enum.any?(fn beam_path ->
      File.stat!(beam_path).mtime > snapshot_mtime
    end)
  end

  defp current_beam_paths do
    app = Mix.Project.config()[:app]
    build_path = Mix.Project.build_path()
    ebin = Path.join([build_path, "lib", to_string(app), "ebin"])

    if File.dir?(ebin) do
      ebin
      |> File.ls!()
      |> Enum.map(&Path.join(ebin, &1))
      |> Enum.filter(&String.ends_with?(&1, ".beam"))
    else
      []
    end
  end

  defp selected_modules(modules, []), do: modules

  defp selected_modules(modules, [query | _]) do
    case Store.find_module(modules, query) do
      {:ok, module_name} ->
        %{module_name => Map.fetch!(modules, module_name)}

      {:error, reason} ->
        Store.report_lookup_error(query, reason)
    end
  end

  defp print_module({module, data}) do
    uncovered =
      data
      |> Map.get("lines", %{})
      |> Enum.reject(fn {_line, line} -> line["covered"] end)
      |> Enum.sort_by(fn {number, _line} -> String.to_integer(number) end)

    if uncovered != [] do
      Mix.shell().info("#{module}: uncovered=#{length(uncovered)}")

      Enum.each(uncovered, fn {number, line} ->
        Mix.shell().info("  #{number} | #{line["text"]}")
      end)
    end
  end
end
