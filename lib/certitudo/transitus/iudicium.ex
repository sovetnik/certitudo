defmodule Certitudo.Transitus.Iudicium do
  @moduledoc """
  Judges match relations into semantic block diffs.
  """

  alias Certitudo.Forma.{Collatio, Differentia, Residuatum, Tractus}

  @spec match(Collatio.t()) :: Differentia.t()
  def match(%Collatio{kind: :same_text_same_coverage} = match) do
    status =
      if same_range?(match.left, match.right) do
        :unchanged
      else
        :moved_unchanged
      end

    %Differentia{status: status, left: match.left, right: match.right}
  end

  def match(%Collatio{kind: :same_text_changed_coverage} = match) do
    %Differentia{
      status: changed_coverage_status(match.left, match.right),
      left: match.left,
      right: match.right
    }
  end

  def match(%Collatio{kind: :left_only, left: left}) do
    %Differentia{
      status: removed_status(left),
      left: left
    }
  end

  def match(%Collatio{kind: :right_only, right: right}) do
    %Differentia{
      status: new_status(right),
      right: right
    }
  end

  def match(%Collatio{kind: :ambiguous} = match) do
    %Differentia{
      status: :ambiguous_moved,
      residue: %Residuatum{
        reason: :ambiguous_block,
        blocks: match.ambiguous
      }
    }
  end

  @spec matches([Collatio.t()]) :: [Differentia.t()]
  def matches(matches) when is_list(matches) do
    Enum.map(matches, &match/1)
  end

  defp same_range?(%Tractus{range: left}, %Tractus{range: right}) do
    left.numbers == right.numbers
  end

  defp changed_coverage_status(left, right) do
    if same_range?(left, right) do
      existing_coverage_status(left, right)
    else
      :moved_coverage_changed
    end
  end

  defp existing_coverage_status(left, right) do
    directions =
      left.lines
      |> Enum.zip(right.lines)
      |> Enum.flat_map(fn {left_line, right_line} ->
        cond do
          not left_line.covered and right_line.covered ->
            [:gained]

          left_line.covered and not right_line.covered ->
            [:lost]

          true ->
            []
        end
      end)
      |> Enum.uniq()

    case directions do
      [:gained] -> :existing_coverage_gained
      [:lost] -> :existing_coverage_lost
      _ -> :existing_coverage_mixed
    end
  end

  defp new_status(%Tractus{} = block) do
    if covered?(block), do: :new_covered, else: :new_uncovered
  end

  defp removed_status(%Tractus{} = block) do
    if covered?(block), do: :removed_covered, else: :removed_uncovered
  end

  defp covered?(%Tractus{lines: lines}) do
    Enum.any?(lines, & &1.covered)
  end
end
