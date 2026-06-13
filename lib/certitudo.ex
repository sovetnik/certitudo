defmodule Certitudo do
  @moduledoc """
  `obducere/2` is the central act behind `mix certitudo`: capture coverage
  from an already-exported `.coverdata` file and compare it against a
  previous snapshot.

  It is a pipeline of four stages, each enriching a shared context map:

  - `Coverage.snapshot/1` — builds the **impressio** from the coverdata
  - `Impressio.resolve/1` — dedupes it against any prior run with the same
    fingerprint
  - `Retentio.resolve/1` — locates the **retentio** (the previous snapshot,
    or an explicit `--since` target)
  - `Discordia.inferentia/1` — diffs the impressio against the retentio,
    if one was found

  Running `mix test` to produce the `.coverdata` is the caller's
  responsibility (`Mix.Tasks.Certitudo`) — `obducere/2` only turns coverage
  data already on disk into impressio/retentio/diff, and returns the
  resulting context map for the caller to report.
  """

  alias Certitudo.Coverage
  alias Certitudo.Discordia
  alias Certitudo.Impressio
  alias Certitudo.Retentio

  @type result :: %{
          run_id: binary(),
          run_label: binary(),
          coverdata_path: binary(),
          snapshot: map(),
          run_dir: binary(),
          kind: Impressio.kind(),
          impressio_run_dir: binary(),
          impressio_snapshot: map(),
          diff: Discordia.diff_result()
        }

  @spec obducere(binary(), keyword()) :: result()
  def obducere(coverdata_path, opts \\ [])
      when is_binary(coverdata_path) and is_list(opts) do
    %{coverdata_path: coverdata_path, opts: opts}
    |> Coverage.snapshot()
    |> Impressio.resolve()
    |> Retentio.resolve()
    |> Discordia.inferentia()
    |> Map.drop([:opts, :retentio])
  end
end
