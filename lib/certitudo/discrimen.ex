defmodule Certitudo.Discrimen do
  @moduledoc """
  Block-first discrimen orchestration for already materializable module entries.
  """

  alias Certitudo.Transitus

  @spec module_pair({binary(), map()}, {binary(), map()}) :: [
          Certitudo.Forma.Differentia.t()
        ]
  def module_pair({name, left}, {name, right}) do
    left_blocks = blocks(name, left)
    right_blocks = blocks(name, right)

    left_blocks
    |> Transitus.Comparatio.blocks(right_blocks)
    |> Transitus.Iudicium.matches()
    |> Transitus.Residuatum.diffs()
  end

  defp blocks(name, data) do
    data
    |> then(&Transitus.Formatio.module(name, &1))
    |> Map.fetch!(:lines)
    |> Transitus.Ordinatio.lines()
    |> Transitus.Congregatio.blocks()
    |> Transitus.Signatio.blocks()
  end
end
