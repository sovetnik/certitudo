defmodule Certitudo.Transitus.Ordinatio do
  @moduledoc """
  Orders structural forms without changing their meaning.
  """

  alias Certitudo.Forma.Line

  @spec lines([Line.t()]) :: [Line.t()]
  def lines(lines) when is_list(lines) do
    Enum.sort_by(lines, & &1.number)
  end
end
