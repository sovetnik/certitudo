defmodule Certitudo.Transitus.Congregatio do
  @moduledoc """
  Groups ordered executable lines into contiguous ranges and blocks.
  """

  alias Certitudo.Forma.{Ambitus, Line, Tractus}

  @spec ranges([Line.t()]) :: [Ambitus.t()]
  def ranges(lines) when is_list(lines) do
    lines
    |> blocks()
    |> Enum.map(& &1.range)
  end

  @spec blocks([Line.t()]) :: [Tractus.t()]
  def blocks(lines) when is_list(lines) do
    lines
    |> Enum.reduce([], &collect_line/2)
    |> Enum.reverse()
    |> Enum.map(&block/1)
  end

  defp collect_line(line, []) do
    [[line]]
  end

  defp collect_line(%Line{} = line, [current | rest]) do
    previous = hd(current)

    if line.number == previous.number + 1 do
      [[line | current] | rest]
    else
      [[line], current | rest]
    end
  end

  defp block(lines) do
    ordered = Enum.reverse(lines)
    numbers = Enum.map(ordered, & &1.number)

    %Tractus{
      range: %Ambitus{
        first: List.first(numbers),
        last: List.last(numbers),
        numbers: numbers
      },
      lines: ordered
    }
  end
end
