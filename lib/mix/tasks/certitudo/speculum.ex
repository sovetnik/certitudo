defmodule Mix.Tasks.Certitudo.Speculum do
  @moduledoc """
  Print a compact coverage summary for one module from a coverage snapshot.

  Usage:
    mix certitudo.speculum "Certitudo.Coverage"
    mix certitudo.speculum "Coverage"
    mix certitudo.speculum "Coverage" --run 20260429T141327Z
    mix certitudo.speculum "Coverage" --snapshot cover/20260429T141327Z/snapshot.json
  """

  use Mix.Task

  alias Certitudo.Report.Store

  @shortdoc "Compact coverage summary for one module"

  @impl Mix.Task
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args,
        strict: [run: :string, snapshot: :string]
      )

    query =
      case positional do
        [value | _] -> value
        _ -> Mix.raise("query is required")
      end

    snapshot_path = Store.snapshot_path!(opts)
    snapshot = Store.read_snapshot!(snapshot_path)
    modules = snapshot["modules"] || %{}

    case Store.find_module(modules, query) do
      {:ok, module_name} ->
        data = Map.fetch!(modules, module_name)

        Mix.shell().info("snapshot: #{snapshot_path}")
        Mix.shell().info("module: #{module_name}")

        Mix.shell().info(
          "coverage: #{data["coverage_percent"]}% (#{data["covered_lines"]}/#{data["executable_lines"]})"
        )

      {:error, reason} ->
        Store.report_lookup_error(query, reason)
    end
  end
end
