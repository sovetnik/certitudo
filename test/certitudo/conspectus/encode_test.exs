defmodule Certitudo.Conspectus.EncodeTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Conspectus.Encode, Forma}

  test "encodes block_diff with nil left (new block)" do
    diff = %Forma.Differentia{
      status: :new_covered,
      left: nil,
      right: block(5, 7)
    }

    assert %{"status" => "new_covered", "left" => nil, "right" => right} =
             Encode.block_diff(diff)

    assert right["range"]["first"] == 5
    assert right["range"]["last"] == 7
  end

  test "encodes block_diff with nil right (removed block)" do
    diff = %Forma.Differentia{
      status: :removed_covered,
      left: block(3, 4),
      right: nil
    }

    assert %{"status" => "removed_covered", "left" => left, "right" => nil} =
             Encode.block_diff(diff)

    assert left["range"]["first"] == 3
  end

  test "encodes residue line_diff with nil left and nil right" do
    residue = %Forma.Residuatum{
      reason: :coverage_changed,
      entries: [
        %Forma.LineaDifferentia{
          status: :new_covered,
          left: nil,
          right: %Forma.Line{number: 5, calls: 1, covered: true, text: "foo"}
        },
        %Forma.LineaDifferentia{
          status: :removed_covered,
          left: %Forma.Line{number: 3, calls: 1, covered: true, text: "bar"},
          right: nil
        }
      ]
    }

    diff = %Forma.Differentia{
      status: :existing_coverage_mixed,
      left: block(1, 2),
      right: block(1, 2),
      residue: residue
    }

    assert %{
             "residue" => %{
               "entries" => [
                 %{
                   "status" => "new_covered",
                   "left" => nil,
                   "right" => %{"number" => 5}
                 },
                 %{
                   "status" => "removed_covered",
                   "left" => %{"number" => 3},
                   "right" => nil
                 }
               ]
             }
           } = Encode.block_diff(diff)
  end

  defp block(first, last) do
    %Forma.Tractus{
      range: %Forma.Ambitus{
        first: first,
        last: last,
        numbers: Enum.to_list(first..last)
      },
      lines: []
    }
  end
end
