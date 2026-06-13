defmodule Certitudo.Transitus.ResiduatumTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Residuatum}

  test "adds changed coverage residue for moved coverage changes" do
    assert %Forma.Differentia{
             residue: %Forma.Residuatum{
               reason: :coverage_changed,
               entries: [
                 %Forma.LineaDifferentia{
                   status: :existing_coverage_lost,
                   left: %Forma.Line{number: 5, covered: true},
                   right: %Forma.Line{number: 9, covered: false}
                 }
               ]
             }
           } =
             Residuatum.diff(%Forma.Differentia{
               status: :moved_coverage_changed,
               left: block(5, [line(5, true, "same")]),
               right: block(9, [line(9, false, "same")])
             })
  end

  test "adds new and removed block residue" do
    right = block(7, [line(7, true, "new")])
    left = block(5, [line(5, false, "old")])

    assert %Forma.Differentia{
             residue: %Forma.Residuatum{
               reason: :new_block,
               entries: [
                 %Forma.LineaDifferentia{
                   status: :new_covered,
                   right: %Forma.Line{number: 7}
                 }
               ]
             }
           } =
             Residuatum.diff(%Forma.Differentia{
               status: :new_covered,
               right: right
             })

    assert %Forma.Differentia{
             residue: %Forma.Residuatum{
               reason: :removed_block,
               entries: [
                 %Forma.LineaDifferentia{
                   status: :removed_uncovered,
                   left: %Forma.Line{number: 5}
                 }
               ]
             }
           } =
             Residuatum.diff(%Forma.Differentia{
               status: :removed_uncovered,
               left: left
             })
  end

  defp block(first, lines) do
    %Forma.Tractus{
      range: %Forma.Ambitus{
        first: first,
        last: first + length(lines) - 1,
        numbers: Enum.map(lines, & &1.number)
      },
      lines: lines
    }
  end

  defp line(number, covered, text) do
    %Forma.Line{
      number: number,
      calls: if(covered, do: 1, else: 0),
      covered: covered,
      text: text
    }
  end
end
