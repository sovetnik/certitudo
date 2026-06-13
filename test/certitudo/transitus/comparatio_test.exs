defmodule Certitudo.Transitus.ComparatioTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Comparatio}

  test "matches unique blocks with same text and same coverage" do
    left = block(5, 7, "text", "coverage")
    right = block(7, 9, "text", "coverage")

    assert [
             %Forma.Collatio{
               kind: :same_text_same_coverage,
               left: ^left,
               right: ^right
             }
           ] = Comparatio.blocks([left], [right])
  end

  test "matches unique blocks with same text and changed coverage" do
    left = block(5, 7, "text", "left-coverage")
    right = block(7, 9, "text", "right-coverage")

    assert [
             %Forma.Collatio{
               kind: :same_text_changed_coverage,
               left: ^left,
               right: ^right
             }
           ] = Comparatio.blocks([left], [right])
  end

  test "keeps unmatched blocks as left only and right only" do
    left = block(5, 7, "left", "coverage")
    right = block(7, 9, "right", "coverage")

    assert [
             %Forma.Collatio{kind: :left_only, left: ^left},
             %Forma.Collatio{kind: :right_only, right: ^right}
           ] = Comparatio.blocks([left], [right])
  end

  test "does not match ambiguous text fingerprints arbitrarily" do
    left_a = block(5, 7, "same", "coverage")
    left_b = block(10, 12, "same", "coverage")
    right = block(7, 9, "same", "coverage")

    assert [
             %Forma.Collatio{
               kind: :ambiguous,
               ambiguous: ambiguous
             }
           ] = Comparatio.blocks([left_a, left_b], [right])

    assert MapSet.new(ambiguous) == MapSet.new([left_a, left_b, right])
  end

  test "blocks without text fingerprint are not matched" do
    left = block(5, 7, nil, "coverage")
    right = block(7, 9, nil, "coverage")

    assert [
             %Forma.Collatio{kind: :left_only, left: ^left},
             %Forma.Collatio{kind: :right_only, right: ^right}
           ] = Comparatio.blocks([left], [right])
  end

  defp block(first, last, text, coverage) do
    %Forma.Tractus{
      range: %Forma.Ambitus{
        first: first,
        last: last,
        numbers: Enum.to_list(first..last)
      },
      lines: [],
      text_fingerprint: text,
      coverage_fingerprint: coverage
    }
  end
end
