defmodule Certitudo.Coverage.Runtime do
  @moduledoc """
  Runtime access to Erlang `:cover` data for snapshot construction.
  """

  @spec import_coverdata!(
          binary(),
          [binary()],
          [module() | Regex.t() | binary()],
          [binary()]
        ) ::
          {[module()], [{module(), integer(), non_neg_integer()}]}
  def import_coverdata!(coverdata_path, prefixes, ignore_modules, beam_dirs)
      when is_binary(coverdata_path) and is_list(prefixes) and
             is_list(ignore_modules) and
             is_list(beam_dirs) do
    ensure_started!()
    compile_beam_dirs!(beam_dirs)
    :ok = apply_cover(:import, [String.to_charlist(coverdata_path)])

    keep_modules = modules(prefixes, ignore_modules)
    keep_set = MapSet.new(keep_modules)

    {
      keep_modules,
      without_io_noise(fn -> bulk_line_coverage(keep_set) end)
    }
  end

  defp compile_beam_dirs!(dirs) when is_list(dirs) do
    Enum.each(dirs, fn dir ->
      if File.dir?(dir) do
        _ = apply_cover(:compile_beam_directory, [String.to_charlist(dir)])
      end
    end)
  end

  defp bulk_line_coverage(keep_set) do
    case apply_cover(:analyse, [:coverage, :line]) do
      {:result, entries} when is_list(entries) ->
        normalize_coverage_entries(entries, keep_set)

      {:result, entries, _meta} when is_list(entries) ->
        normalize_coverage_entries(entries, keep_set)

      other ->
        raise ArgumentError,
              "Unexpected :cover.analyse(:coverage, :line) result: #{inspect(other, limit: 5)}"
    end
  end

  defp normalize_coverage_entries(entries, keep_set) do
    entries
    |> Enum.reduce(%{}, fn
      {{mod, line}, {1, 0}}, acc when line != 0 ->
        if MapSet.member?(keep_set, mod) do
          Map.put(acc, {mod, line}, 1)
        else
          acc
        end

      {{mod, line}, {0, 1}}, acc when line != 0 ->
        if MapSet.member?(keep_set, mod) do
          Map.put_new(acc, {mod, line}, 0)
        else
          acc
        end

      _entry, acc ->
        acc
    end)
    |> Enum.map(fn {{mod, line}, state} -> {mod, line, state} end)
  end

  @spec keep_module?(module(), [binary()], [module() | Regex.t() | binary()]) ::
          boolean()
  def keep_module?(mod, prefixes, ignore_modules)
      when is_atom(mod) and is_list(prefixes) and is_list(ignore_modules) do
    mod_name = to_string(mod)
    prefixed?(mod_name, prefixes) and not ignored?(mod, ignore_modules)
  end

  defp modules(prefixes, ignore_modules)
       when is_list(prefixes) and is_list(ignore_modules) do
    apply_cover(:modules, [])
    |> Enum.filter(fn mod ->
      keep_module?(mod, prefixes, ignore_modules)
    end)
    |> Enum.sort_by(&to_string/1)
  end

  defp prefixed?(module_name, prefixes) when is_list(prefixes) do
    Enum.any?(prefixes, &String.starts_with?(module_name, &1))
  end

  defp ignored?(mod, ignore_modules)
       when is_atom(mod) and is_list(ignore_modules) do
    Enum.any?(ignore_modules, fn
      %Regex{} = regex ->
        Regex.match?(regex, inspect(mod))

      exact_mod when is_atom(exact_mod) ->
        mod == exact_mod

      pattern when is_binary(pattern) ->
        inspect(mod) == pattern

      _other ->
        false
    end)
  end

  defp ensure_started! do
    ensure_cover_module!()

    # :cover keeps imported module data across calls within the same VM.
    # Stopping first discards any data left over from a previous import
    # (e.g. another project's coverdata with overlapping module names),
    # avoiding "Deleting data for module ..." warnings on re-import.
    apply_cover(:stop, [])

    case apply_cover(:start, []) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp apply_cover(fun, args) do
    :erlang.apply(:cover, fun, args)
  end

  defp without_io_noise(fun) when is_function(fun, 0) do
    old_leader = Process.group_leader()
    {:ok, io} = StringIO.open("")
    Process.group_leader(self(), io)

    try do
      fun.()
    after
      Process.group_leader(self(), old_leader)
      _ = StringIO.close(io)
    end
  end

  defp ensure_cover_module! do
    if Code.ensure_loaded?(:cover) do
      :ok
    else
      root = :code.root_dir() |> List.to_string()
      lib_dir = Path.join(root, "lib")

      tools_dir =
        lib_dir
        |> File.ls!()
        |> Enum.find(&String.starts_with?(&1, "tools-"))

      if is_binary(tools_dir) do
        ebin = Path.join([lib_dir, tools_dir, "ebin"])
        true = :code.add_pathz(String.to_charlist(ebin))
      end

      if Code.ensure_loaded?(:cover) do
        :ok
      else
        raise ArgumentError,
              "Unable to load :cover module from Erlang tools ebin"
      end
    end
  end
end
