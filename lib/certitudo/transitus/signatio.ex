defmodule Certitudo.Transitus.Signatio do
  @moduledoc """
  Signs blocks with text and coverage fingerprints.
  """

  alias Certitudo.Forma.Tractus

  @spec block(Tractus.t()) :: Tractus.t()
  def block(%Tractus{} = block) do
    %Tractus{
      block
      | text_fingerprint: text_fingerprint(block.lines),
        coverage_fingerprint: coverage_fingerprint(block.lines)
    }
  end

  @spec blocks([Tractus.t()]) :: [Tractus.t()]
  def blocks(blocks) when is_list(blocks) do
    Enum.map(blocks, &block/1)
  end

  defp text_fingerprint(lines) do
    if Enum.all?(lines, &is_binary(&1.text)) do
      lines
      |> Enum.map(& &1.text)
      |> fingerprint()
    end
  end

  defp coverage_fingerprint(lines) do
    lines
    |> Enum.map(fn line -> if line.covered, do: "1", else: "0" end)
    |> fingerprint()
  end

  defp fingerprint(parts) do
    parts
    |> Enum.join("\n")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
