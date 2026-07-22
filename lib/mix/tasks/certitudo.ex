defmodule Mix.Tasks.Certitudo do
  @moduledoc """
  Run tests, capture coverage, and compare against a previous snapshot.

  Each run produces an **impressio** — the current coverage snapshot. If an
  identical impressio already exists (same fingerprint), it is reused and
  labelled *Deja vu*. The snapshot we compare against is the **retentio** —
  either the most recent prior run or an explicit `--since` target.

  Output written to `.certitudo/<run_id>/`:
  - `snapshot.json` — the impressio
  - `coverage.coverdata` — raw Erlang cover data
  - `diff.prev.json` — differentia between retentio and impressio (when available)

  ```
  mix certitudo
  mix certitudo --example
  mix certitudo --no-color
  mix certitudo --label scenario -- --only scenario
  mix certitudo --from-coverdata cover/covprobe.coverdata
  mix certitudo --no-auto-diff
  mix certitudo --since 20260605T190458Z
  ```

  Pass `--no-color` to disable ANSI colors in Certitudo's own output.
  Pass `--example` to render the bundled demonstration diff with all statuses,
  without running tests or comparing snapshots.

  ## Related tasks

  - `mix certitudo.discrimen` — compare any two snapshots explicitly
  - `mix certitudo.inspectio` — inspect and prune `.certitudo/` artifacts
  - `mix certitudo.lacunae` — show uncovered lines
  - `mix certitudo.speculum` — print a snapshot as a coverage table
  """

  use Mix.Task

  alias Certitudo.Coverage
  alias Certitudo.Coverage.Runtime

  @shortdoc "Create coverage snapshot (+ optional diff.prev)"

  @impl Mix.Task
  def run(args) do
    {opts, passthrough, _invalid} =
      OptionParser.parse(args,
        strict: [
          example: :boolean,
          label: :string,
          run_id: :string,
          since: :string,
          from_coverdata: :string,
          auto_diff: :boolean,
          color: :boolean,
          prefix: :keep
        ],
        allow_nonexistent_atoms: true
      )

    shell_info("Signa obductionis quaerimus", opts)

    if Keyword.get(opts, :example, false) do
      print_example(opts)
    else
      run_id = opts[:run_id] || Coverage.timestamp_id()

      opts =
        opts
        |> Keyword.put(:run_id, run_id)
        |> put_runtime_defaults()

      coverdata_path =
        case opts[:from_coverdata] do
          nil ->
            run_tests_and_export_coverdata!(run_id, passthrough)

          path ->
            path
        end

      result = Certitudo.obducere(coverdata_path, opts)

      shell_info("", opts)

      case result.kind do
        :new ->
          "impressio: #{Path.basename(result.impressio_run_dir)}"
          |> shell_info(opts)

        :known ->
          "Deja vu! seen at #{Path.basename(result.impressio_run_dir)}"
          |> shell_info(opts, :yellow)

          "impressio: #{Path.basename(result.impressio_run_dir)}"
          |> shell_info(opts)
      end

      print_diff(result.diff, opts)

      "Certitudo: #{coverage_label(result.snapshot["totals"]["coverage_percent"])} for #{result.snapshot["totals"]["modules"]} modules"
      |> shell_info(opts)

      shell_info("", opts)
      maybe_hint_since(Path.basename(result.impressio_run_dir), opts)
    end
  end

  defp coverage_label(nil), do: "coverage not measured (no modules matched)"
  defp coverage_label(percent), do: "#{percent}%"

  defp run_tests_and_export_coverdata!(run_id, passthrough) do
    export_name = "export_#{run_id}"

    test_args =
      ["test", "--cover", "--export-coverage", export_name] ++ passthrough

    {_, status} =
      System.cmd("mix", test_args,
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    if status != 0 do
      Mix.raise("mix test failed with status #{status}")
    end

    Path.join("cover", "#{export_name}.coverdata")
  end

  defp put_runtime_defaults(opts) do
    app = Mix.Project.config()[:app]
    build_path = Mix.Project.build_path()
    beam_dirs = [Path.join([build_path, "lib", to_string(app), "ebin"])]

    prefixes = Keyword.get_values(opts, :prefix)

    own_modules =
      case prefixes do
        # no explicit --prefix: scope to what's actually compiled for this
        # app (Runtime.own_module_names/1 — physical .beam files under
        # beam_dirs, not a guess from the app name).
        [] -> Runtime.own_module_names(beam_dirs)
        # explicit --prefix given: caller's intent is authoritative, don't
        # additively widen it back out with every compiled module.
        _ -> MapSet.new()
      end

    ignore_modules =
      case Mix.Project.config()[:test_coverage] do
        cfg when is_list(cfg) -> Keyword.get(cfg, :ignore_modules, [])
        _ -> []
      end

    opts
    |> Keyword.put(:prefixes, prefixes)
    |> Keyword.put(:own_modules, own_modules)
    |> Keyword.put(:ignore_modules, ignore_modules)
    |> Keyword.put(:beam_dirs, beam_dirs)
  end

  defp print_example(opts) do
    diff =
      example_diff_path()
      |> File.read!()
      |> Jason.decode!()

    shell_info("", opts)
    print_auto_diff_modules(diff, opts)
    shell_info(example_summary(), opts)
    shell_info("", opts)
  end

  defp example_diff_path do
    Path.join([File.cwd!(), "examples", "example.diff.json"])
  end

  defp example_summary do
    "\nCertitudo: 89.23% for 42 modules"
  end

  defp print_diff({:ok, %{retentio_path: retentio_path, diff: diff}}, opts) do
    "retentio: #{Path.basename(Path.dirname(retentio_path))}"
    |> shell_info(opts)

    shell_info("", opts)
    print_auto_diff_modules(diff, opts)
    shell_info("", opts)
  end

  defp print_diff({:since_not_found, since}, opts) do
    shell_info(
      "warning: --since #{since} not found, skipping diff",
      opts,
      :yellow
    )
  end

  defp print_diff(:skipped, _opts), do: :ok

  defp maybe_hint_since(run_id, opts) do
    if is_nil(Keyword.get(opts, :since)) do
      shell_info(
        "since: to compare future runs against this snapshot:",
        opts
      )

      shell_info("  mix certitudo --since #{run_id}", opts)
    end
  end

  defp print_auto_diff_modules(%{"changed_modules" => changed}, opts)
       when is_list(changed) do
    if changed == [] do
      shell_info("Identical: coverage not changed", opts, :blue)
    else
      shell_info("Differentia (#{length(changed)} modules):", opts, :blue)

      Enum.each(changed, fn mod ->
        module = mod["module"]
        source_changed = mod["source_changed"] || false
        block_diffs = mod["block_diffs"] || []

        shell_info(
          "  #{module}: block_diffs=#{length(block_diffs)} source_changed=#{source_changed}",
          opts,
          :blue
        )

        print_block_diffs(block_diffs, opts)
      end)
    end
  end

  defp print_block_diffs(block_diffs, opts) when is_list(block_diffs) do
    block_diffs
    |> Enum.filter(&printable_block_diff?/1)
    |> Enum.take(20)
    |> Enum.chunk_by(& &1["status"])
    |> Enum.each(&print_block_chunk(&1, opts))
  end

  defp print_block_chunk([%{"status" => "moved_unchanged"} = diff], opts) do
    shell_info("    moved_unchanged: #{diff_range(diff)}", opts, :magenta)
  end

  defp print_block_chunk(
         [%{"status" => "moved_unchanged"} | _] = chunk,
         opts
       ) do
    ranges = Enum.map_join(chunk, ", ", &diff_range/1)

    shell_info(
      "    moved_unchanged (#{length(chunk)}): #{ranges}",
      opts,
      :magenta
    )
  end

  defp print_block_chunk(chunk, opts) do
    Enum.each(chunk, fn diff ->
      color = status_color(diff["status"])

      shell_info(
        "    #{diff["status"]}: #{diff_range(diff)}",
        opts,
        color
      )

      print_residue(diff["residue"], opts)
    end)
  end

  defp printable_block_diff?(diff) do
    diff["status"] != "unchanged" and diff_range(diff) != "none"
  end

  defp print_residue(%{"entries" => entries}, opts) when is_list(entries) do
    Enum.each(entries, fn entry ->
      status = entry["status"]
      line = entry["right"] || entry["left"]

      shell_info(
        "      #{line_symbol(status)} #{line["number"]} | #{line["text"]}",
        opts,
        status_color(status)
      )
    end)
  end

  defp print_residue(_residue, _opts), do: :ok

  defp block_range(nil), do: "none"

  defp block_range(%{"range" => %{"first" => first, "last" => last}}),
    do: "#{first}-#{last}"

  defp diff_range(%{"left" => left, "right" => right}) do
    left_range = block_range(left)
    right_range = block_range(right)

    if left_range == right_range do
      left_range
    else
      "#{left_range} -> #{right_range}"
    end
  end

  defp status_color("new_covered"), do: :green
  defp status_color("existing_coverage_gained"), do: :green
  defp status_color("new_uncovered"), do: :orange
  defp status_color("removed_uncovered"), do: :yellow
  defp status_color("removed_covered"), do: :red
  defp status_color("existing_coverage_lost"), do: :red
  defp status_color("existing_coverage_mixed"), do: :purple
  defp status_color("moved_unchanged"), do: :magenta
  defp status_color("moved_coverage_changed"), do: :purple
  defp status_color("ambiguous_moved"), do: :cyan

  defp status_color(status),
    do: Mix.raise("unknown coverage status: #{inspect(status)}")

  defp line_symbol("new_covered"), do: "+"
  defp line_symbol("new_uncovered"), do: "+"
  defp line_symbol("removed_covered"), do: "-"
  defp line_symbol("removed_uncovered"), do: "-"
  defp line_symbol("existing_coverage_gained"), do: "~"
  defp line_symbol("existing_coverage_lost"), do: "~"

  defp line_symbol(status),
    do: Mix.raise("unknown coverage line status: #{inspect(status)}")

  defp shell_info(text, opts, color \\ :blue)
       when is_binary(text) and is_list(opts) do
    case Keyword.get(opts, :color, true) do
      false ->
        Mix.shell().info(text)

      true ->
        Mix.shell().info(colorize(text, color))
    end
  end

  defp colorize(text, color) when is_atom(color) do
    color
    |> ansi_color()
    |> Kernel.++([text, :reset])
    |> IO.ANSI.format()
    |> IO.iodata_to_binary()
  end

  defp ansi_color(:orange), do: ["\e[38;5;208m"]
  defp ansi_color(:purple), do: ["\e[38;5;183m"]
  defp ansi_color(color), do: [color]
end
