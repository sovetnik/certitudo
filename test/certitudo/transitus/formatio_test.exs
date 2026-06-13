defmodule Certitudo.Transitus.FormatioTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Forma, Transitus.Formatio}

  test "materializes snapshot lines" do
    assert %Forma.Conspectus{
             schema_version: 2,
             run: %{"id" => "left"},
             modules: %{
               "Elixir.Certitudo.A" => %Forma.Module{
                 name: "Elixir.Certitudo.A",
                 lines: lines
               }
             }
           } =
             Formatio.snapshot(%{
               "schema_version" => 2,
               "run" => %{"id" => "left"},
               "modules" => %{
                 "Elixir.Certitudo.A" => %{
                   "lines" => %{
                     "11" => %{
                       "calls" => 0,
                       "covered" => false,
                       "text" => "right"
                     },
                     "10" => %{
                       "calls" => 1,
                       "covered" => true,
                       "text" => "left"
                     }
                   }
                 }
               }
             })

    assert [
             %Forma.Line{number: 10, calls: 1, covered: true},
             %Forma.Line{number: 11, calls: 0, covered: false}
           ] = Enum.sort_by(lines, & &1.number)
  end

  test "materializes line identity" do
    assert %Forma.Line{
             number: 7,
             calls: 1,
             covered: true,
             text: "def foobar(arg) do"
           } =
             Formatio.line("7", %{
               "calls" => 1,
               "covered" => true,
               "text" => "def foobar(arg) do"
             })
  end
end
