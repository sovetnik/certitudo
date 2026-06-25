defmodule Certitudo.Conspectus.Build do
  @moduledoc """
  Build conspectus maps from materialized cover line data.
  """

  alias Certitudo.Conspectus.Source

  @spec from_lines(binary(), keyword(), [module()], [
          {module(), integer(), non_neg_integer()}
        ]) ::
          map()
  def from_lines(coverdata_path, opts, keep_modules, bulk_lines)
      when is_binary(coverdata_path) and is_list(opts) and
             is_list(keep_modules) and
             is_list(bulk_lines) do
    prefixes = Keyword.fetch!(opts, :prefixes)
    ignore_modules = Keyword.fetch!(opts, :ignore_modules)
    run_id = Keyword.fetch!(opts, :run_id)
    run_label = Keyword.fetch!(opts, :run_label)
    beam_dirs = Keyword.fetch!(opts, :beam_dirs)

    lines_by_module =
      Enum.group_by(bulk_lines, fn {mod, _line, _state} -> mod end)

    modules =
      keep_modules
      |> Enum.reduce(%{}, fn mod, acc ->
        mod_name = to_string(mod)

        lines =
          Enum.map(Map.get(lines_by_module, mod, []), fn {_mod, line, state} ->
            {line, state}
          end)

        mod = String.to_atom(mod_name)
        Map.put(acc, mod_name, module_entry(mod, lines, beam_dirs))
      end)

    %{
      "schema_version" => 2,
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "run" => %{
        "id" => run_id,
        "label" => run_label,
        "coverdata_path" => Path.expand(coverdata_path),
        "beam_dirs" => Enum.map(beam_dirs, &Path.expand/1)
      },
      "filter" => %{
        "prefixes" => prefixes,
        "ignore_modules" => Enum.map(ignore_modules, &inspect/1)
      },
      "totals" => totals(modules),
      "modules" => modules
    }
  end

  defp module_entry(mod, lines, beam_dirs) do
    {source_path, source_size, source_sha256} = Source.meta(mod, beam_dirs)

    normalized =
      Map.new(lines, fn {line, calls} ->
        {
          normalize_line(line),
          %{
            "calls" => calls,
            "covered" => calls > 0,
            "text" => Source.line(source_path, line)
          }
        }
      end)

    executable_lines = map_size(normalized)

    covered_lines =
      Enum.count(normalized, fn {_line, data} -> data["covered"] end)

    %{
      "source" => source_path,
      "source_size" => source_size,
      "source_sha256" => source_sha256,
      "executable_lines" => executable_lines,
      "covered_lines" => covered_lines,
      "coverage_percent" => percent(covered_lines, executable_lines),
      "lines" => normalized
    }
  end

  defp totals(modules) do
    {covered, executable} =
      Enum.reduce(modules, {0, 0}, fn {_name, mod}, {c_acc, e_acc} ->
        {c_acc + mod["covered_lines"], e_acc + mod["executable_lines"]}
      end)

    %{
      "covered_lines" => covered,
      "executable_lines" => executable,
      "coverage_percent" => percent(covered, executable, map_size(modules)),
      "modules" => map_size(modules)
    }
  end

  defp percent(_covered, 0), do: 100.0

  defp percent(covered, executable),
    do: Float.round(covered / executable * 100.0, 2)

  # No modules matched the filter at all — cannot measure, must not claim 100%.
  defp percent(_covered, 0, 0), do: nil

  # Modules matched, but every one of them genuinely has zero executable
  # lines (e.g. a project consisting only of moduledoc/behaviour stubs) —
  # legitimately 100%, same reasoning as the 2-arg per-module clause.
  defp percent(_covered, 0, _module_count), do: 100.0

  defp percent(covered, executable, _module_count),
    do: Float.round(covered / executable * 100.0, 2)

  defp normalize_line(line) when is_integer(line) and line > 0,
    do: Integer.to_string(line)

  defp normalize_line(line) do
    raise ArgumentError, "invalid cover line number: #{inspect(line)}"
  end
end
