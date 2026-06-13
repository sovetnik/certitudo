defmodule Certitudo.Transitus.SignatioTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Signatio}

  test "signs block text and coverage identity" do
    block = %Forma.Tractus{
      range: %Forma.Ambitus{first: 5, last: 6, numbers: [5, 6]},
      lines: [
        %Forma.Line{
          number: 5,
          calls: 1,
          covered: true,
          text: "left"
        },
        %Forma.Line{
          number: 6,
          calls: 0,
          covered: false,
          text: "right"
        }
      ]
    }

    assert %Forma.Tractus{
             text_fingerprint: text,
             coverage_fingerprint: coverage
           } = Signatio.block(block)

    assert is_binary(text)
    assert is_binary(coverage)
    assert text != coverage
  end

  test "does not invent text identity when a line lacks text" do
    block = %Forma.Tractus{
      range: %Forma.Ambitus{first: 5, last: 6, numbers: [5, 6]},
      lines: [
        %Forma.Line{
          number: 5,
          calls: 1,
          covered: true,
          text: "left"
        },
        %Forma.Line{
          number: 6,
          calls: 0,
          covered: false
        }
      ]
    }

    assert %Forma.Tractus{
             text_fingerprint: nil,
             coverage_fingerprint: coverage
           } = Signatio.block(block)

    assert is_binary(coverage)
  end

  test "signs multiple blocks" do
    assert [
             %Forma.Tractus{coverage_fingerprint: first},
             %Forma.Tractus{coverage_fingerprint: second}
           ] =
             Signatio.blocks([
               block([true]),
               block([false])
             ])

    assert first != second
  end

  defp block(covered) do
    lines =
      covered
      |> Enum.with_index(1)
      |> Enum.map(fn {covered?, number} ->
        %Forma.Line{
          number: number,
          calls: if(covered?, do: 1, else: 0),
          covered: covered?,
          text: "line-#{number}"
        }
      end)

    %Forma.Tractus{
      range: %Forma.Ambitus{
        first: 1,
        last: length(lines),
        numbers: Enum.map(lines, & &1.number)
      },
      lines: lines
    }
  end
end
