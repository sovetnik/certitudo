defmodule Mix.Tasks.CertitudoTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Certitudo

  test "is available as a mix task" do
    assert Code.ensure_loaded?(Mix.Tasks.Certitudo)
    assert function_exported?(Mix.Tasks.Certitudo, :run, 1)
  end

  test "inspectio is available as a mix task" do
    assert Code.ensure_loaded?(Mix.Tasks.Certitudo.Inspectio)
    assert function_exported?(Mix.Tasks.Certitudo.Inspectio, :run, 1)
  end

  test "lacunae is available as a mix task" do
    assert Code.ensure_loaded?(Mix.Tasks.Certitudo.Lacunae)
    assert function_exported?(Mix.Tasks.Certitudo.Lacunae, :run, 1)
  end

  test "--example renders the bundled diff fixture" do
    output =
      capture_io(fn ->
        Certitudo.run(["--example", "--no-color"])
      end)

    assert output =~ "new_covered: none -> 10-10"
    assert output =~ "moved_unchanged: 30-35 -> 31-37"
    assert output =~ "ambiguous_moved: 50-50 -> 54-54"
    assert output =~ "Certitudo: 89.23% for 42 modules"
  end
end
