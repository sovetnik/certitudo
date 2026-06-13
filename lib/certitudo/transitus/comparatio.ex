defmodule Certitudo.Transitus.Comparatio do
  @moduledoc """
  Compares signed blocks and produces match relations.
  """

  alias Certitudo.Forma.{Collatio, Tractus}

  @spec blocks([Tractus.t()], [Tractus.t()]) :: [
          Collatio.t()
        ]
  def blocks(left_blocks, right_blocks)
      when is_list(left_blocks) and is_list(right_blocks) do
    {exact_matches, left_blocks, right_blocks} =
      exact_range_matches(left_blocks, right_blocks)

    left_by_text = index_by_text(left_blocks)
    right_by_text = index_by_text(right_blocks)

    matched_texts =
      left_by_text
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.intersection(Map.keys(right_by_text) |> MapSet.new())

    matches =
      matched_texts
      |> Enum.sort()
      |> Enum.map(fn text ->
        match_text(text, left_by_text, right_by_text)
      end)

    matched_left = matched_blocks(matches, :left)
    matched_right = matched_blocks(matches, :right)

    left_only =
      left_blocks
      |> Enum.reject(&MapSet.member?(matched_left, &1))
      |> Enum.map(&%Collatio{kind: :left_only, left: &1})

    right_only =
      right_blocks
      |> Enum.reject(&MapSet.member?(matched_right, &1))
      |> Enum.map(&%Collatio{kind: :right_only, right: &1})

    exact_matches ++ matches ++ left_only ++ right_only
  end

  defp exact_range_matches(left_blocks, right_blocks) do
    right_by_exact = Map.new(right_blocks, &{exact_key(&1), &1})

    {matches, matched_left, matched_right} =
      Enum.reduce(left_blocks, {[], MapSet.new(), MapSet.new()}, fn left,
                                                                    {
                                                                      matches,
                                                                      matched_left,
                                                                      matched_right
                                                                    } ->
        right = Map.get(right_by_exact, exact_key(left))

        if right do
          {
            [
              %Collatio{
                kind: match_kind(left, right),
                left: left,
                right: right
              }
              | matches
            ],
            MapSet.put(matched_left, left),
            MapSet.put(matched_right, right)
          }
        else
          {matches, matched_left, matched_right}
        end
      end)

    left_rest = Enum.reject(left_blocks, &MapSet.member?(matched_left, &1))

    right_rest =
      Enum.reject(right_blocks, &MapSet.member?(matched_right, &1))

    {Enum.reverse(matches), left_rest, right_rest}
  end

  defp match_kind(left, right) do
    if left.coverage_fingerprint == right.coverage_fingerprint,
      do: :same_text_same_coverage,
      else: :same_text_changed_coverage
  end

  defp exact_key(block) do
    {block.range.numbers, block.text_fingerprint}
  end

  defp index_by_text(blocks) do
    blocks
    |> Enum.reject(&is_nil(&1.text_fingerprint))
    |> Enum.group_by(& &1.text_fingerprint)
  end

  defp match_text(text, left_by_text, right_by_text) do
    left = Map.fetch!(left_by_text, text)
    right = Map.fetch!(right_by_text, text)

    case {left, right} do
      {[left_block], [right_block]} ->
        kind =
          if left_block.coverage_fingerprint ==
               right_block.coverage_fingerprint do
            :same_text_same_coverage
          else
            :same_text_changed_coverage
          end

        %Collatio{kind: kind, left: left_block, right: right_block}

      _ ->
        %Collatio{kind: :ambiguous, ambiguous: left ++ right}
    end
  end

  defp matched_blocks(matches, side) do
    matches
    |> Enum.flat_map(fn
      %Collatio{kind: :ambiguous, ambiguous: blocks}
      when is_list(blocks) ->
        blocks

      match ->
        [Map.fetch!(match, side)]
    end)
    |> MapSet.new()
  end
end
