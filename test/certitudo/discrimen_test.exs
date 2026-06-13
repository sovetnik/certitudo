defmodule Certitudo.DiscrimenTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Discrimen, Forma}

  test "reports shifted block as moved unchanged" do
    left =
      module_entry(%{
        "5" => line(1, "def foobar(arg) do"),
        "6" => line(1, "bar(arg)"),
        "7" => line(1, "end")
      })

    right =
      module_entry(%{
        "7" => line(1, "def foobar(arg) do"),
        "8" => line(1, "bar(arg)"),
        "9" => line(1, "end")
      })

    assert [
             %Forma.Differentia{
               status: :moved_unchanged,
               left: %Forma.Tractus{range: %Forma.Ambitus{first: 5, last: 7}},
               right: %Forma.Tractus{
                 range: %Forma.Ambitus{first: 7, last: 9}
               },
               residue: nil
             }
           ] =
             Discrimen.module_pair(
               {"Elixir.Certitudo.A", left},
               {"Elixir.Certitudo.A", right}
             )
  end

  defp module_entry(lines) do
    %{
      "source" => "lib/a.ex",
      "lines" => lines
    }
  end

  defp line(calls, text) do
    %{
      "calls" => calls,
      "covered" => calls > 0,
      "text" => text
    }
  end
end
