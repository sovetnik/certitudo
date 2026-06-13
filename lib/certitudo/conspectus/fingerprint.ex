defmodule Certitudo.Conspectus.Fingerprint do
  @moduledoc """
  Semantic fingerprint for coverage conspectus.
  """

  @stable_keys ["schema_version", "filter", "modules", "totals"]

  @spec calculate(map()) :: binary()
  def calculate(snapshot) when is_map(snapshot) do
    snapshot
    |> Map.take(@stable_keys)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
