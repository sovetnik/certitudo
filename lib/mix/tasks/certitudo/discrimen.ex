defmodule Mix.Tasks.Certitudo.Discrimen do
  @moduledoc """
  Compare two snapshots explicitly: a retentio (older) and an impressio (newer).

  Each argument may be:
  - a run id under `.certitudo/<run_id>/`
  - a run directory path
  - a direct `snapshot.json` path

  ```
  mix certitudo.discrimen 20260329T041500Z 20260329T043000Z
  mix certitudo.discrimen .certitudo/retentio .certitudo/impressio --out tmp/diff.json
  ```
  """

  use Mix.Task

  alias Certitudo.Coverage

  @shortdoc "Compare two coverage snapshots"

  @impl Mix.Task
  def run(args) do
    {opts, positional, _invalid} =
      OptionParser.parse(args, strict: [out: :string])

    case positional do
      [left_arg, right_arg] ->
        left_path = Coverage.resolve_snapshot_path(left_arg)
        right_path = Coverage.resolve_snapshot_path(right_arg)

        left = Coverage.read_snapshot(left_path)
        right = Coverage.read_snapshot(right_path)
        diff = Coverage.diff(left, right)

        out_path =
          opts[:out] ||
            Path.join(
              Coverage.certitudo_dir(),
              "diff_#{left["run"]["id"]}_vs_#{right["run"]["id"]}.json"
            )

        File.mkdir_p!(Path.dirname(out_path))
        File.write!(out_path, Jason.encode_to_iodata!(diff, pretty: true))

        Mix.shell().info("diff: #{out_path}")
        Mix.shell().info("added_modules: #{diff["summary"]["added"]}")
        Mix.shell().info("removed_modules: #{diff["summary"]["removed"]}")
        Mix.shell().info("changed_modules: #{diff["summary"]["changed"]}")

      _ ->
        Mix.raise(
          "Usage: mix certitudo.discrimen <left> <right> [--out path]"
        )
    end
  end
end
