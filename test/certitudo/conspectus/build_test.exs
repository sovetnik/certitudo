defmodule Certitudo.Conspectus.BuildTest do
  use ExUnit.Case, async: true

  alias Certitudo.Conspectus.Build

  test "from_lines builds snapshot structure from real module data" do
    bulk_lines = [
      {Certitudo.Coverage, 10, 1},
      {Certitudo.Coverage, 11, 0}
    ]

    snapshot =
      Build.from_lines(
        "cover/test.coverdata",
        opts("build-test"),
        [Certitudo.Coverage],
        bulk_lines
      )

    assert snapshot["schema_version"] == 2
    assert snapshot["run"]["id"] == "build-test"
    assert snapshot["run"]["label"] == "test"
    assert is_binary(snapshot["generated_at"])
    assert snapshot["totals"]["modules"] == 1

    mod = snapshot["modules"]["Elixir.Certitudo.Coverage"]
    assert mod["executable_lines"] == 2
    assert mod["covered_lines"] == 1
    assert mod["lines"]["10"]["covered"] == true
    assert mod["lines"]["11"]["covered"] == false
  end

  test "from_lines with no modules produces 100% total coverage" do
    snapshot =
      Build.from_lines("cover/test.coverdata", opts("empty"), [], [])

    assert snapshot["totals"]["modules"] == 0
    assert snapshot["totals"]["coverage_percent"] == 100.0
  end

  test "from_lines stores expanded coverdata path" do
    snapshot =
      Build.from_lines("cover/test.coverdata", opts("path-test"), [], [])

    assert Path.type(snapshot["run"]["coverdata_path"]) == :absolute
    assert snapshot["run"]["beam_dirs"] == [Path.expand(beam_dir())]
  end

  test "from_lines raises for invalid line number" do
    assert_raise ArgumentError, ~r/invalid cover line number/, fn ->
      Build.from_lines(
        "cover/test.coverdata",
        opts("bad-line"),
        [Certitudo.Coverage],
        [{Certitudo.Coverage, 0, 1}]
      )
    end
  end

  defp opts(run_id) do
    [
      prefixes: ["Elixir.Certitudo."],
      ignore_modules: [],
      run_id: run_id,
      run_label: "test",
      beam_dirs: [beam_dir()]
    ]
  end

  defp beam_dir do
    app = Mix.Project.config()[:app]
    Path.join([Mix.Project.build_path(), "lib", to_string(app), "ebin"])
  end
end
