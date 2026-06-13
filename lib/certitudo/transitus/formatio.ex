defmodule Certitudo.Transitus.Formatio do
  @moduledoc """
  Gives structural form to raw snapshot map data.

  Formatio does not compare versions and does not assign diff meaning.
  """

  alias Certitudo.Forma.{Conspectus, Line}

  @spec snapshot(map()) :: Conspectus.t()
  def snapshot(
        %{
          "schema_version" => schema_version,
          "run" => run,
          "modules" => modules
        } = data
      )
      when is_integer(schema_version) and is_map(run) and is_map(modules) do
    %Conspectus{
      schema_version: schema_version,
      run: run,
      filter: Map.get(data, "filter"),
      totals: Map.get(data, "totals"),
      modules: formatio_modules(modules)
    }
  end

  @spec module(binary(), map()) :: Certitudo.Forma.Module.t()
  def module(name, data) when is_binary(name) and is_map(data) do
    %Certitudo.Forma.Module{
      name: name,
      source: Map.get(data, "source"),
      source_size: Map.get(data, "source_size"),
      source_sha256: Map.get(data, "source_sha256"),
      coverage_percent: Map.get(data, "coverage_percent"),
      covered_lines: Map.get(data, "covered_lines"),
      executable_lines: Map.get(data, "executable_lines"),
      lines: formatio_lines(Map.fetch!(data, "lines"))
    }
  end

  @spec line(binary(), map()) :: Line.t()
  def line(number, data) when is_binary(number) and is_map(data) do
    calls = Map.fetch!(data, "calls")

    %Line{
      number: parse_line_number!(number),
      calls: calls,
      covered: Map.get(data, "covered", calls > 0),
      text: Map.get(data, "text")
    }
  end

  defp formatio_modules(modules) do
    Map.new(modules, fn {name, data} -> {name, module(name, data)} end)
  end

  defp formatio_lines(lines) when is_map(lines) do
    lines
    |> Enum.map(fn {number, data} -> line(number, data) end)
  end

  defp parse_line_number!(number) do
    case Integer.parse(number) do
      {line, ""} when line > 0 -> line
    end
  end
end
