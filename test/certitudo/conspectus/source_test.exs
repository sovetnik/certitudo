defmodule Certitudo.Conspectus.SourceTest do
  use ExUnit.Case, async: true

  alias Certitudo.Conspectus.Source

  test "meta returns source path, size, and sha256 for a known module" do
    {source, size, sha} = Source.meta(Certitudo.Coverage, [beam_dir()])

    assert is_binary(source) and String.ends_with?(source, ".ex")
    assert is_integer(size) and size > 0
    assert is_binary(sha) and byte_size(sha) == 64
  end

  test "meta returns nils when module not found in beam_dirs" do
    assert {nil, nil, nil} = Source.meta(Certitudo.Coverage, [])
  end

  test "line returns nil for nil source" do
    assert Source.line(nil, 1) == nil
  end

  test "line returns text for a valid integer line number" do
    source = source_path(Certitudo.Coverage)
    assert is_binary(Source.line(source, 1))
  end

  test "line accepts string line number" do
    source = source_path(Certitudo.Coverage)
    assert Source.line(source, 1) == Source.line(source, "1")
  end

  test "line returns nil for out-of-range line" do
    source = source_path(Certitudo.Coverage)
    assert Source.line(source, 999_999) == nil
  end

  test "line returns nil for non-numeric string" do
    source = source_path(Certitudo.Coverage)
    assert Source.line(source, "not_a_number") == nil
  end

  test "meta returns nils when beam file is not a valid beam" do
    tmp = System.tmp_dir!()
    File.write!(Path.join(tmp, "Elixir.FakeGarbage.beam"), "not a beam file")
    assert {nil, nil, nil} = Source.meta(FakeGarbage, [tmp])
  end

  test "meta returns nils when beam has no source in compile_info" do
    tmp = System.tmp_dir!()
    beam_path = Path.join(tmp, "Elixir.FakeNoSource.beam")

    # compile from abstract forms — produces compile_info with no :source key
    forms = [
      {:attribute, 1, :module, :FakeNoSource},
      {:attribute, 2, :export, []}
    ]

    {:ok, :FakeNoSource, beam_binary} =
      :compile.forms(forms, [:return_errors])

    File.write!(beam_path, beam_binary)
    assert {nil, nil, nil} = Source.meta(FakeNoSource, [tmp])
  end

  defp beam_dir do
    app = Mix.Project.config()[:app]
    Path.join([Mix.Project.build_path(), "lib", to_string(app), "ebin"])
  end

  defp source_path(mod) do
    beam_path = Path.join(beam_dir(), "#{mod}.beam")

    {:ok, {_, [{:compile_info, info}]}} =
      :beam_lib.chunks(String.to_charlist(beam_path), [:compile_info])

    List.to_string(Keyword.fetch!(info, :source))
  end
end
