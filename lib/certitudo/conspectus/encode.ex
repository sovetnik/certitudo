defmodule Certitudo.Conspectus.Encode do
  @moduledoc """
  JSON-compatible encoding for conspectus differentia forms.
  """

  @spec block_diff(struct()) :: map()
  def block_diff(diff) do
    %{
      "status" => Atom.to_string(diff.status),
      "left" => block(diff.left),
      "right" => block(diff.right),
      "residue" => residue(diff.residue)
    }
  end

  defp block(nil), do: nil

  defp block(block) do
    %{
      "range" => range(block.range),
      "lines" => Enum.map(block.lines, &line/1)
    }
  end

  defp range(range) do
    %{
      "first" => range.first,
      "last" => range.last,
      "numbers" => range.numbers
    }
  end

  defp line(nil), do: nil

  defp line(line) do
    %{
      "number" => line.number,
      "calls" => line.calls,
      "covered" => line.covered,
      "text" => line.text
    }
  end

  defp residue(nil), do: nil

  defp residue(residue) do
    %{
      "reason" => Atom.to_string(residue.reason),
      "entries" => Enum.map(residue.entries || [], &line_diff/1),
      "blocks" => Enum.map(residue.blocks || [], &block/1),
      "details" => residue.details
    }
  end

  defp line_diff(line_diff) do
    %{
      "status" => Atom.to_string(line_diff.status),
      "left" => line(line_diff.left),
      "right" => line(line_diff.right)
    }
  end
end
