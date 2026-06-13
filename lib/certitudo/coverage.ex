defmodule Certitudo.Coverage do
  @moduledoc """
  Versioned coverage snapshots and block-first structural diffs.
  """

  alias Certitudo.Conspectus
  alias Certitudo.Coverage.Runtime
  alias Certitudo.Discrimen

  @certitudo_dir ".certitudo"

  @spec certitudo_dir() :: binary()
  def certitudo_dir do
    File.mkdir_p!(@certitudo_dir)
    @certitudo_dir
  end

  @spec resolve_prefixes(keyword()) :: [binary()]
  def resolve_prefixes(opts) when is_list(opts) do
    case Keyword.get_values(opts, :prefix) do
      [] -> Keyword.fetch!(opts, :prefixes)
      values -> values
    end
  end

  @doc """
  Stage: builds the impressio snapshot from `ctx.coverdata_path` and
  `ctx.opts`, adding `:run_id`, `:run_label`, `:snapshot` and `:run_dir`.
  """
  @spec snapshot(map()) :: map()
  def snapshot(%{coverdata_path: coverdata_path, opts: opts} = ctx) do
    run_id = opts[:run_id] || timestamp_id()
    run_label = opts[:label] || "coverage"

    snapshot =
      create_snapshot_from_coverdata(coverdata_path,
        run_id: run_id,
        run_label: run_label,
        prefixes: resolve_prefixes(opts),
        beam_dirs: Keyword.fetch!(opts, :beam_dirs),
        ignore_modules: Keyword.fetch!(opts, :ignore_modules)
      )

    ctx
    |> Map.put(:run_id, run_id)
    |> Map.put(:run_label, run_label)
    |> Map.put(:snapshot, snapshot)
    |> Map.put(:run_dir, unique_run_dir(run_id))
  end

  @spec create_snapshot_from_coverdata(binary(), keyword()) :: map()
  def create_snapshot_from_coverdata(coverdata_path, opts \\ [])
      when is_binary(coverdata_path) and is_list(opts) do
    prefixes = Keyword.fetch!(opts, :prefixes)
    ignore_modules = Keyword.fetch!(opts, :ignore_modules)
    run_id = Keyword.get(opts, :run_id, default_run_id())
    run_label = Keyword.get(opts, :run_label, "coverage")
    beam_dirs = Keyword.fetch!(opts, :beam_dirs)

    {keep_modules, bulk_lines} =
      Runtime.import_coverdata!(
        coverdata_path,
        prefixes,
        ignore_modules,
        beam_dirs
      )

    Conspectus.Build.from_lines(
      coverdata_path,
      [
        prefixes: prefixes,
        ignore_modules: ignore_modules,
        run_id: run_id,
        run_label: run_label,
        beam_dirs: beam_dirs
      ],
      keep_modules,
      bulk_lines
    )
    |> put_fingerprint()
  end

  @spec fingerprint(map()) :: binary()
  def fingerprint(snapshot) when is_map(snapshot) do
    Conspectus.Fingerprint.calculate(snapshot)
  end

  @spec write_snapshot(map(), binary()) :: binary()
  def write_snapshot(snapshot, run_dir)
      when is_map(snapshot) and is_binary(run_dir) do
    File.mkdir_p!(run_dir)
    path = Path.join(run_dir, "snapshot.json")
    File.write!(path, Jason.encode_to_iodata!(snapshot, pretty: true))
    path
  end

  defp put_fingerprint(snapshot),
    do: Map.put(snapshot, "fingerprint", fingerprint(snapshot))

  @spec diff(map(), map()) :: map()
  def diff(
        %{"modules" => left_modules} = left,
        %{"modules" => right_modules} = right
      )
      when is_map(left_modules) and is_map(right_modules) do
    left_names = Map.keys(left_modules) |> MapSet.new()
    right_names = Map.keys(right_modules) |> MapSet.new()

    added =
      MapSet.difference(right_names, left_names)
      |> MapSet.to_list()
      |> Enum.sort()

    removed =
      MapSet.difference(left_names, right_names)
      |> MapSet.to_list()
      |> Enum.sort()

    changed =
      MapSet.intersection(left_names, right_names)
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.reduce([], fn name, acc ->
        left_entry = Map.fetch!(left_modules, name)
        right_entry = Map.fetch!(right_modules, name)

        source_changed =
          left_entry["source_sha256"] != right_entry["source_sha256"] or
            left_entry["source_size"] != right_entry["source_size"]

        block_diffs =
          Discrimen.module_pair({name, left_entry}, {name, right_entry})

        unchanged? =
          not source_changed and
            Enum.all?(block_diffs, &(&1.status == :unchanged))

        if unchanged? do
          acc
        else
          [
            %{
              "module" => name,
              "source_changed" => source_changed,
              "left" => %{
                "coverage_percent" => left_entry["coverage_percent"],
                "covered_lines" => left_entry["covered_lines"],
                "executable_lines" => left_entry["executable_lines"],
                "source_sha256" => left_entry["source_sha256"],
                "source_size" => left_entry["source_size"]
              },
              "right" => %{
                "coverage_percent" => right_entry["coverage_percent"],
                "covered_lines" => right_entry["covered_lines"],
                "executable_lines" => right_entry["executable_lines"],
                "source_sha256" => right_entry["source_sha256"],
                "source_size" => right_entry["source_size"]
              },
              "block_diffs" =>
                Enum.map(block_diffs, &Conspectus.Encode.block_diff/1)
            }
            | acc
          ]
        end
      end)
      |> Enum.reverse()

    %{
      "schema_version" => 2,
      "left_run" => left["run"],
      "right_run" => right["run"],
      "summary" => %{
        "modules_left" => map_size(left_modules),
        "modules_right" => map_size(right_modules),
        "added" => length(added),
        "removed" => length(removed),
        "changed" => length(changed)
      },
      "added_modules" => added,
      "removed_modules" => removed,
      "changed_modules" => changed
    }
  end

  @spec read_snapshot(binary()) :: map()
  def read_snapshot(path) when is_binary(path) do
    path |> File.read!() |> Jason.decode!()
  end

  @spec find_snapshot_path(binary()) :: binary() | nil
  def find_snapshot_path(arg) when is_binary(arg) do
    cond do
      File.regular?(arg) ->
        arg

      File.regular?(Path.join(arg, "snapshot.json")) ->
        Path.join(arg, "snapshot.json")

      File.regular?(Path.join([@certitudo_dir, arg, "snapshot.json"])) ->
        Path.join([@certitudo_dir, arg, "snapshot.json"])

      true ->
        nil
    end
  end

  @spec resolve_snapshot_path(binary()) :: binary()
  def resolve_snapshot_path(arg) when is_binary(arg) do
    find_snapshot_path(arg) ||
      raise ArgumentError,
            "Cannot resolve snapshot path from #{inspect(arg)}"
  end

  @spec timestamp_id() :: binary()
  def timestamp_id do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  @spec unique_run_dir(binary()) :: binary()
  def unique_run_dir(run_id) when is_binary(run_id) do
    base = Path.join(@certitudo_dir, run_id)
    if File.exists?(base), do: find_free(base, 1), else: base
  end

  defp find_free(base, idx) do
    candidate = "#{base}-#{idx}"
    if File.exists?(candidate), do: find_free(base, idx + 1), else: candidate
  end

  defp default_run_id, do: timestamp_id()
end
