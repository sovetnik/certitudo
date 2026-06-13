defmodule Certitudo.Impressio do
  @moduledoc """
  Resolves the current snapshot (impressio) — either newly created or an
  already-known duplicate with the same fingerprint.
  """

  alias Certitudo.Coverage

  @type kind :: :new | :known

  @doc """
  Stage: resolves the impressio for `ctx.snapshot` against `ctx.run_dir` /
  `ctx.coverdata_path`, adding `:kind`, `:impressio_run_dir` and
  `:impressio_snapshot`.
  """
  @spec resolve(map()) :: map()
  def resolve(
        %{
          snapshot: snapshot,
          run_dir: run_dir,
          coverdata_path: coverdata_path
        } = ctx
      ) do
    {kind, impressio_run_dir, impressio_snapshot} =
      resolve(snapshot, run_dir, coverdata_path)

    ctx
    |> Map.put(:kind, kind)
    |> Map.put(:impressio_run_dir, impressio_run_dir)
    |> Map.put(:impressio_snapshot, impressio_snapshot)
  end

  @spec resolve(map(), binary(), binary()) :: {kind(), binary(), map()}
  def resolve(snapshot, run_dir, coverdata_path) do
    case find_duplicate(snapshot) do
      nil ->
        Coverage.write_snapshot(snapshot, run_dir)
        File.cp!(coverdata_path, Path.join(run_dir, "coverage.coverdata"))
        {:new, run_dir, snapshot}

      existing_path ->
        existing_snapshot = Coverage.read_snapshot(existing_path)
        stored_run_dir = Path.dirname(existing_path)
        {:known, stored_run_dir, existing_snapshot}
    end
  end

  @spec find_duplicate(map()) :: binary() | nil
  def find_duplicate(%{"fingerprint" => fingerprint})
      when is_binary(fingerprint) do
    certitudo_dir = Coverage.certitudo_dir()

    certitudo_dir
    |> File.ls!()
    |> Enum.map(&Path.join([certitudo_dir, &1, "snapshot.json"]))
    |> Enum.filter(&File.regular?/1)
    |> Enum.find(fn path ->
      case read_snapshot_safe(path) do
        %{"fingerprint" => ^fingerprint} -> true
        _other -> false
      end
    end)
  end

  def find_duplicate(_snapshot), do: nil

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
