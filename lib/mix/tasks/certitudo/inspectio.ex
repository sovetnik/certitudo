defmodule Mix.Tasks.Certitudo.Inspectio do
  @moduledoc """
  Inspect `.certitudo/` artifacts and optionally remove old coverage runs.

  Usage:
    mix certitudo.inspectio
    mix certitudo.inspectio --keep 5
  """

  use Mix.Task

  alias Certitudo.Coverage
  alias Certitudo.Report.Store

  @prompt_threshold 99
  @preferred_cli_env :test

  @shortdoc "Inspect .certitudo artifacts"

  @impl Mix.Task
  def run(args) do
    {opts, _positional, _invalid} =
      OptionParser.parse(args, strict: [keep: :integer])

    cover_dir = Coverage.certitudo_dir()
    summary = report(cover_dir)

    keep =
      case opts[:keep] do
        nil -> prompted_keep(summary)
        number -> number
      end

    if is_integer(keep) and keep > 0 do
      purge(cover_dir, keep)
      Mix.shell().info("purged: true")
      Mix.shell().info("kept_reports: #{keep}")
      report(cover_dir)
    else
      Mix.shell().info("purged: false")
    end
  end

  defp report(cover_dir) do
    files = files_under(cover_dir)
    report_dirs = report_dirs(cover_dir)

    Mix.shell().info("cover_dir: #{cover_dir}")
    Mix.shell().info("files: #{length(files)}")
    Mix.shell().info("reports: #{length(report_dirs)}")
    Mix.shell().info("size: #{format_bytes(total_size(files))}")

    report_dirs
    |> Enum.reverse()
    |> Enum.each(fn dir ->
      dir_files = files_under(dir)

      Mix.shell().info(
        "  #{dir}: files=#{length(dir_files)} size=#{format_bytes(total_size(dir_files))}"
      )
    end)

    %{
      files: length(files),
      reports: length(report_dirs),
      size: total_size(files)
    }
  end

  defp prompted_keep(%{reports: reports}) when reports > @prompt_threshold do
    ".certitudo has #{reports} reports; keep how many fresh reports? "
    |> Mix.shell().prompt()
    |> parse_keep()
  end

  defp prompted_keep(_summary), do: nil

  defp parse_keep(value) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {number, ""} -> number
      _other -> nil
    end
  end

  defp purge(cover_dir, keep) do
    cover_dir
    |> entries()
    |> Enum.filter(
      &(File.regular?(&1) and String.ends_with?(&1, ".coverdata"))
    )
    |> Enum.each(&File.rm!/1)

    cover_dir
    |> report_dirs()
    |> Enum.drop(keep)
    |> Enum.each(&File.rm_rf!/1)
  end

  defp report_dirs(cover_dir) do
    cover_dir
    |> entries()
    |> Enum.filter(&(File.dir?(&1) and Store.report_dir?(&1)))
    |> Enum.sort_by(fn dir -> File.stat!(dir).mtime end, :desc)
  end

  defp entries(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.map(&Path.join(dir, &1))
    else
      []
    end
  end

  defp files_under(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.flat_map(fn entry -> expand_entry(Path.join(dir, entry)) end)
    else
      []
    end
  end

  defp expand_entry(path) do
    cond do
      File.regular?(path) -> [path]
      File.dir?(path) -> files_under(path)
      true -> []
    end
  end

  defp total_size(files) do
    Enum.reduce(files, 0, fn file, acc -> acc + File.stat!(file).size end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"

  defp format_bytes(bytes) when bytes < 1024 * 1024 do
    "#{Float.round(bytes / 1024, 1)} KiB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / 1024 / 1024, 1)} MiB"
  end
end
