defmodule Certitudo.Transitus.IudiciumTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Iudicium}

  test "judges same range as unchanged" do
    block = block(5, 7, [true])

    assert %Forma.Differentia{status: :unchanged} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_same_coverage,
               left: block,
               right: block
             })
  end

  test "judges changed range as moved unchanged" do
    assert %Forma.Differentia{status: :moved_unchanged} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_same_coverage,
               left: block(5, 7, [true]),
               right: block(7, 9, [true])
             })
  end

  test "judges moved same text changed coverage" do
    assert %Forma.Differentia{status: :moved_coverage_changed} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_changed_coverage,
               left: block(5, 7, [true]),
               right: block(7, 9, [false])
             })
  end

  test "judges same range gained coverage" do
    assert %Forma.Differentia{status: :existing_coverage_gained} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_changed_coverage,
               left: block(5, 6, [false, false]),
               right: block(5, 6, [true, true])
             })
  end

  test "judges same range lost coverage" do
    assert %Forma.Differentia{status: :existing_coverage_lost} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_changed_coverage,
               left: block(5, 6, [true, true]),
               right: block(5, 6, [false, false])
             })
  end

  test "judges same range mixed coverage" do
    assert %Forma.Differentia{status: :existing_coverage_mixed} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_changed_coverage,
               left: block(5, 6, [true, false]),
               right: block(5, 6, [false, true])
             })
  end

  test "judges same range mixed coverage with an unchanged line" do
    # middle line stays covered on both sides — hits the true -> [] branch
    assert %Forma.Differentia{status: :existing_coverage_mixed} =
             Iudicium.match(%Forma.Collatio{
               kind: :same_text_changed_coverage,
               left: block(5, 7, [true, true, false]),
               right: block(5, 7, [false, true, true])
             })
  end

  test "judges new and removed blocks by coverage state" do
    assert %Forma.Differentia{status: :new_covered} =
             Iudicium.match(%Forma.Collatio{
               kind: :right_only,
               right: block(5, 7, [false, true])
             })

    assert %Forma.Differentia{status: :removed_uncovered} =
             Iudicium.match(%Forma.Collatio{
               kind: :left_only,
               left: block(5, 7, [false])
             })
  end

  test "judges ambiguous match as ambiguous moved" do
    assert %Forma.Differentia{
             status: :ambiguous_moved,
             residue: %Forma.Residuatum{reason: :ambiguous_block}
           } =
             Iudicium.match(%Forma.Collatio{
               kind: :ambiguous,
               ambiguous: [block(5, 7, [true])]
             })
  end

  defp block(first, last, covered) do
    lines =
      covered
      |> Enum.with_index(first)
      |> Enum.map(fn {covered?, number} ->
        %Forma.Line{number: number, calls: 0, covered: covered?}
      end)

    %Forma.Tractus{
      range: %Forma.Ambitus{
        first: first,
        last: last,
        numbers: Enum.to_list(first..last)
      },
      lines: lines
    }
  end
end
