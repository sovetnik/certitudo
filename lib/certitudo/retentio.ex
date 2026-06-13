defmodule Certitudo.Retentio do
  @moduledoc """
  Resolves the previous snapshot (retentio) — what the current impressio is
  compared against. Either the most recent prior run or an explicit --since target.
  """

  alias Certitudo.Coverage

  @type resolution ::
          {:ok, binary()} | {:since_not_found, binary()} | :skipped

  @doc """
  Stage: locates the retentio for `ctx.impressio_run_dir`, adding
  `:retentio` — `{:ok, path}`, `{:since_not_found, since}` (an explicit
  `--since` target doesn't exist), or `:skipped` (`--no-auto-diff`).
  Computing the actual diff is `Discordia.inferentia/1`'s job.
  """
  @spec resolve(map()) :: map()
  def resolve(
        %{opts: opts, run_dir: run_dir, impressio_run_dir: impressio_run_dir} =
          ctx
      ) do
    Map.put(ctx, :retentio, resolve(opts, run_dir, impressio_run_dir))
  end

  @spec resolve(keyword(), binary(), binary()) :: resolution()
  def resolve(opts, current_run_dir, impressio_run_dir) do
    if Keyword.get(opts, :auto_diff, true) do
      since = Keyword.get(opts, :since)

      case find(
             current_run_dir,
             Keyword.put(opts, :exclude_run_dirs, [impressio_run_dir])
           ) do
        nil when is_binary(since) -> {:since_not_found, since}
        nil -> :skipped
        retentio_path -> {:ok, retentio_path}
      end
    else
      :skipped
    end
  end

  @spec find(binary(), keyword()) :: binary() | nil
  def find(impressio_run_dir, opts \\ []) do
    case Keyword.get(opts, :since) do
      nil ->
        previous(impressio_run_dir, Keyword.get(opts, :exclude_run_dirs, []))

      since ->
        Coverage.find_snapshot_path(since)
    end
  end

  @spec previous(binary()) :: binary() | nil
  def previous(current_run_dir), do: previous(current_run_dir, [])

  @spec previous(binary(), [binary()]) :: binary() | nil
  def previous(current_run_dir, exclude_run_dirs) do
    excluded_abs =
      [current_run_dir | exclude_run_dirs]
      |> Enum.map(&Path.expand/1)
      |> MapSet.new()

    certitudo_dir = Coverage.certitudo_dir()

    certitudo_dir
    |> File.ls!()
    |> Enum.map(&Path.join([certitudo_dir, &1]))
    |> Enum.reject(fn dir ->
      MapSet.member?(excluded_abs, Path.expand(dir))
    end)
    |> Enum.map(&Path.join(&1, "snapshot.json"))
    |> Enum.filter(&(File.regular?(&1) and valid?(&1)))
    |> case do
      [] -> nil
      paths -> Enum.max_by(paths, fn path -> File.stat!(path).mtime end)
    end
  end

  defp valid?(path) do
    case read_snapshot_safe(path) do
      %{
        "schema_version" => 2,
        "modules" => modules,
        "run" => %{"label" => label, "coverdata_path" => coverdata_path}
      }
      when is_map(modules) and is_binary(label) and is_binary(coverdata_path) ->
        true

      _other ->
        false
    end
  end

  defp read_snapshot_safe(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      data
    else
      {:error, reason} ->
        Mix.shell().error(
          "invalid snapshot skipped: #{path} (#{inspect(reason)})"
        )

        nil
    end
  end
end
