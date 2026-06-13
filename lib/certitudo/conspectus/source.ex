defmodule Certitudo.Conspectus.Source do
  @moduledoc """
  Source metadata and source-line lookup for conspectus construction.
  """

  @spec meta(module(), [binary()]) ::
          {binary() | nil, non_neg_integer() | nil, binary() | nil}
  def meta(mod, beam_dirs) when is_atom(mod) and is_list(beam_dirs) do
    source =
      mod
      |> beam_path(beam_dirs)
      |> source_from_beam()

    if is_binary(source) and File.regular?(source) do
      bin = File.read!(source)

      {
        source,
        byte_size(bin),
        Base.encode16(:crypto.hash(:sha256, bin), case: :lower)
      }
    else
      {source, nil, nil}
    end
  end

  @spec line(binary() | nil, binary() | integer()) :: binary() | nil
  def line(nil, _line), do: nil

  def line(source, line)
      when is_binary(source) and is_binary(line) do
    case Integer.parse(line) do
      {n, ""} when n > 0 ->
        line(source, n)

      _ ->
        nil
    end
  end

  def line(source, line)
      when is_binary(source) and is_integer(line) do
    if File.regular?(source) do
      source
      |> File.stream!(:line, [])
      |> Enum.at(line - 1)
      |> case do
        nil -> nil
        text -> String.trim_trailing(text)
      end
    else
      nil
    end
  end

  defp beam_path(mod, beam_dirs) do
    beam_name = "#{mod}.beam"

    beam_dirs
    |> Enum.map(&Path.join(&1, beam_name))
    |> Enum.find(&File.regular?/1)
  end

  defp source_from_beam(nil), do: nil

  defp source_from_beam(beam_path) when is_binary(beam_path) do
    case :beam_lib.chunks(String.to_charlist(beam_path), [:compile_info]) do
      {:ok, {_mod, [{:compile_info, info}]}} ->
        case Keyword.get(info, :source) do
          src when is_list(src) -> List.to_string(src)
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
