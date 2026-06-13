defmodule Certitudo.FormaTest do
  use ExUnit.Case, async: true

  alias Certitudo.Forma

  test "line is an executable line fact" do
    assert %Forma.Line{
             number: 7,
             calls: 1,
             covered: true,
             text: "def foobar(arg) do"
           } = %Forma.Line{
             number: 7,
             calls: 1,
             covered: true,
             text: "def foobar(arg) do"
           }
  end

  test "tractus is an ambitus with ordered executable lines" do
    range = %Forma.Ambitus{first: 5, last: 7, numbers: [5, 6, 7]}

    lines = [
      %Forma.Line{number: 5, calls: 1, covered: true},
      %Forma.Line{number: 6, calls: 1, covered: true},
      %Forma.Line{number: 7, calls: 1, covered: true}
    ]

    assert %Forma.Tractus{
             range: ^range,
             lines: ^lines,
             text_fingerprint: "text",
             coverage_fingerprint: "coverage"
           } = %Forma.Tractus{
             range: range,
             lines: lines,
             text_fingerprint: "text",
             coverage_fingerprint: "coverage"
           }
  end

  test "differentia keeps semantic status separate from tractus" do
    assert %Forma.Differentia{
             status: :moved_unchanged,
             left: %Forma.Tractus{},
             right: %Forma.Tractus{},
             residue: nil
           } = %Forma.Differentia{
             status: :moved_unchanged,
             left: %Forma.Tractus{
               range: %Forma.Ambitus{first: 5, last: 7, numbers: [5, 6, 7]},
               lines: []
             },
             right: %Forma.Tractus{
               range: %Forma.Ambitus{first: 7, last: 9, numbers: [7, 8, 9]},
               lines: []
             }
           }
  end
end
