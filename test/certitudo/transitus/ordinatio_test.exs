defmodule Certitudo.Transitus.OrdinatioTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Ordinatio}

  test "orders executable lines by line number" do
    assert [
             %Forma.Line{number: 5},
             %Forma.Line{number: 7},
             %Forma.Line{number: 9}
           ] =
             Ordinatio.lines([
               %Forma.Line{number: 9, calls: 0, covered: false},
               %Forma.Line{number: 5, calls: 1, covered: true},
               %Forma.Line{number: 7, calls: 1, covered: true}
             ])
  end
end
