defmodule Certitudo.Transitus.CongregatioTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Congregatio}

  test "groups contiguous executable lines into ranges" do
    assert [
             %Forma.Ambitus{first: 5, last: 7, numbers: [5, 6, 7]},
             %Forma.Ambitus{first: 10, last: 11, numbers: [10, 11]}
           ] =
             Congregatio.ranges([
               line(5),
               line(6),
               line(7),
               line(10),
               line(11)
             ])
  end

  test "groups contiguous executable lines into blocks" do
    lines = [
      line(5, "def foobar(arg) do"),
      line(6, "bar(arg)"),
      line(7, "end"),
      line(10, "def baz(), do: :ok")
    ]

    assert [
             %Forma.Tractus{
               range: %Forma.Ambitus{first: 5, last: 7},
               lines: [
                 %Forma.Line{number: 5, text: "def foobar(arg) do"},
                 %Forma.Line{number: 6, text: "bar(arg)"},
                 %Forma.Line{number: 7, text: "end"}
               ],
               text_fingerprint: nil,
               coverage_fingerprint: nil
             },
             %Forma.Tractus{
               range: %Forma.Ambitus{first: 10, last: 10},
               lines: [%Forma.Line{number: 10, text: "def baz(), do: :ok"}]
             }
           ] = Congregatio.blocks(lines)
  end

  defp line(number, text \\ nil) do
    %Forma.Line{
      number: number,
      calls: 1,
      covered: true,
      text: text
    }
  end
end
