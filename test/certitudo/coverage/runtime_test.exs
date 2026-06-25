defmodule Certitudo.Coverage.RuntimeTest do
  use ExUnit.Case, async: true

  alias Certitudo.Coverage.Runtime

  describe "own_module_names/1" do
    setup do
      dir =
        Path.join(
          System.tmp_dir!(),
          "certitudo_runtime_test_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "Elixir.Umwelt.beam"), "")
      File.write!(Path.join(dir, "Elixir.Umwelt.Phases.beam"), "")
      File.write!(Path.join(dir, "not_a_beam_file.txt"), "")

      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, dir: dir}
    end

    test "lists module names derived from .beam filenames, ignoring other files",
         %{
           dir: dir
         } do
      assert Runtime.own_module_names([dir]) ==
               MapSet.new(["Elixir.Umwelt", "Elixir.Umwelt.Phases"])
    end

    test "returns an empty set for a nonexistent directory" do
      assert Runtime.own_module_names(["/no/such/dir"]) == MapSet.new()
    end

    test "merges names across multiple beam_dirs", %{dir: dir} do
      other =
        Path.join(
          System.tmp_dir!(),
          "certitudo_runtime_test_other_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(other)
      File.write!(Path.join(other, "Elixir.Jason.beam"), "")
      on_exit(fn -> File.rm_rf!(other) end)

      assert Runtime.own_module_names([dir, other]) ==
               MapSet.new([
                 "Elixir.Umwelt",
                 "Elixir.Umwelt.Phases",
                 "Elixir.Jason"
               ])
    end
  end

  describe "keep_module?/4" do
    test "keeps a module matching a prefix, regardless of own_modules" do
      assert Runtime.keep_module?(
               Certitudo.Coverage,
               ["Elixir.Certitudo."],
               []
             )
    end

    test "keeps a module present in own_modules even without a matching prefix" do
      own_modules = MapSet.new(["Elixir.Umwelt"])

      assert Runtime.keep_module?(Umwelt, [], [], own_modules)
      refute Runtime.keep_module?(Jason, [], [], own_modules)
    end

    test "ignore_modules excludes a module even if it matches own_modules" do
      own_modules = MapSet.new(["Elixir.Umwelt"])

      refute Runtime.keep_module?(Umwelt, [], [Umwelt], own_modules)
    end

    test "defaults own_modules to empty when omitted (prefix-only behavior unchanged)" do
      refute Runtime.keep_module?(Umwelt, [], [])
    end
  end
end
