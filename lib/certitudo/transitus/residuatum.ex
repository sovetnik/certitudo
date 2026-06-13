defmodule Certitudo.Transitus.Residuatum do
  @moduledoc """
  Adds line-level residue only after block judgment.
  """

  alias Certitudo.Forma.{Differentia, LineaDifferentia, Residuatum, Tractus}

  @spec diff(Differentia.t()) :: Differentia.t()
  def diff(%Differentia{status: :moved_coverage_changed} = diff) do
    %Differentia{diff | residue: changed(diff.left, diff.right)}
  end

  def diff(%Differentia{status: status} = diff)
      when status in [
             :existing_coverage_gained,
             :existing_coverage_lost,
             :existing_coverage_mixed
           ] do
    %Differentia{diff | residue: changed(diff.left, diff.right)}
  end

  def diff(%Differentia{status: status, right: %Tractus{} = block} = diff)
      when status in [:new_covered, :new_uncovered] do
    %Differentia{
      diff
      | residue: %Residuatum{
          reason: :new_block,
          entries: new_entries(block)
        }
    }
  end

  def diff(%Differentia{status: status, left: %Tractus{} = block} = diff)
      when status in [:removed_covered, :removed_uncovered] do
    %Differentia{
      diff
      | residue: %Residuatum{
          reason: :removed_block,
          entries: removed_entries(block)
        }
    }
  end

  def diff(%Differentia{} = diff), do: diff

  @spec diffs([Differentia.t()]) :: [Differentia.t()]
  def diffs(diffs) when is_list(diffs) do
    Enum.map(diffs, &diff/1)
  end

  defp changed(left, right) do
    right_by_text = Map.new(right.lines, &{&1.text, &1})

    entries =
      left.lines
      |> Enum.flat_map(fn left_line ->
        right_line = Map.get(right_by_text, left_line.text)

        if right_line && left_line.covered != right_line.covered do
          [
            %LineaDifferentia{
              status: coverage_status(left_line, right_line),
              left: left_line,
              right: right_line
            }
          ]
        else
          []
        end
      end)

    %Residuatum{reason: :coverage_changed, entries: entries}
  end

  defp coverage_status(left, right) do
    cond do
      not left.covered and right.covered -> :existing_coverage_gained
      left.covered and not right.covered -> :existing_coverage_lost
    end
  end

  defp new_entries(block) do
    Enum.map(block.lines, fn line ->
      %LineaDifferentia{
        status: if(line.covered, do: :new_covered, else: :new_uncovered),
        right: line
      }
    end)
  end

  defp removed_entries(block) do
    Enum.map(block.lines, fn line ->
      %LineaDifferentia{
        status:
          if(line.covered, do: :removed_covered, else: :removed_uncovered),
        left: line
      }
    end)
  end
end
