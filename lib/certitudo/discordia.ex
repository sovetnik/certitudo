defmodule Certitudo.Discordia do
  @moduledoc """
  Infers the discordia — the diff — between the impressio and the retentio
  that `Retentio.resolve/1` located — or carries forward why there's nothing
  to diff.
  """

  alias Certitudo.Coverage

  @type diff_result ::
          {:ok, %{retentio_path: binary(), diff: map(), diff_path: binary()}}
          | {:since_not_found, binary()}
          | :skipped

  @doc """
  Stage: turns `ctx.retentio` into `:diff`. Writes `diff.prev.json` into
  `ctx.impressio_run_dir` when a retentio was found.
  """
  @spec inferentia(map()) :: map()
  def inferentia(%{retentio: {:ok, retentio_path}} = ctx) do
    %{impressio_run_dir: impressio_run_dir} = ctx
    impressio_path = Path.join(impressio_run_dir, "snapshot.json")

    diff = comparare(retentio_path, impressio_path)
    diff_path = scribere(impressio_run_dir, diff)

    Map.put(
      ctx,
      :diff,
      {:ok,
       %{retentio_path: retentio_path, diff: diff, diff_path: diff_path}}
    )
  end

  def inferentia(%{retentio: not_found} = ctx),
    do: Map.put(ctx, :diff, not_found)

  @doc """
  Reads the snapshots at `retentio_path` and `impressio_path` and returns the
  differentia between them.
  """
  @spec comparare(binary(), binary()) :: map()
  def comparare(retentio_path, impressio_path) do
    prev = Coverage.read_snapshot(retentio_path)
    curr = Coverage.read_snapshot(impressio_path)
    Coverage.diff(prev, curr)
  end

  @spec scribere(binary(), map()) :: binary()
  defp scribere(impressio_run_dir, diff) do
    diff_path = Path.join(impressio_run_dir, "diff.prev.json")
    File.write!(diff_path, Jason.encode_to_iodata!(diff, pretty: true))
    diff_path
  end
end
