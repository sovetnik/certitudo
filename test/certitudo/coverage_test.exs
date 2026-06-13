defmodule Certitudo.CoverageTest do
  use ExUnit.Case, async: true

  alias Certitudo.{Coverage, Coverage.Runtime}

  test "diff reports added removed and changed modules" do
    left = %{
      "run" => %{"id" => "left"},
      "modules" => %{
        "Elixir.Certitudo.A" => %{
          "coverage_percent" => 50.0,
          "covered_lines" => 1,
          "executable_lines" => 2,
          "source_sha256" => "aaa",
          "source_size" => 10,
          "lines" => %{
            "10" => line_entry(1, "same"),
            "11" => line_entry(0, "changed")
          }
        },
        "Elixir.Certitudo.B" => %{
          "coverage_percent" => 100.0,
          "covered_lines" => 1,
          "executable_lines" => 1,
          "source_sha256" => "bbb",
          "source_size" => 20,
          "lines" => %{"20" => line_entry(1, "removed")}
        }
      }
    }

    right = %{
      "run" => %{"id" => "right"},
      "modules" => %{
        "Elixir.Certitudo.A" => %{
          "coverage_percent" => 50.0,
          "covered_lines" => 1,
          "executable_lines" => 2,
          "source_sha256" => "ccc",
          "source_size" => 11,
          "lines" => %{
            "10" => line_entry(0, "same"),
            "11" => line_entry(1, "changed")
          }
        },
        "Elixir.Certitudo.C" => %{
          "coverage_percent" => 100.0,
          "covered_lines" => 1,
          "executable_lines" => 1,
          "source_sha256" => "ddd",
          "source_size" => 30,
          "lines" => %{"30" => line_entry(1, "added")}
        }
      }
    }

    assert %{
             "summary" => %{
               "added" => 1,
               "removed" => 1,
               "changed" => 1
             },
             "added_modules" => ["Elixir.Certitudo.C"],
             "removed_modules" => ["Elixir.Certitudo.B"],
             "changed_modules" => [
               %{
                 "module" => "Elixir.Certitudo.A",
                 "source_changed" => true,
                 "block_diffs" => block_diffs
               }
             ]
           } = Coverage.diff(left, right)

    assert Enum.map(block_diffs, & &1["status"]) == [
             "existing_coverage_mixed"
           ]
  end

  test "diff ignores unchanged modules" do
    snapshot = %{
      "run" => %{"id" => "same"},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{"10" => line_entry(1, "same")})
      }
    }

    assert %{
             "summary" => %{"changed" => 0},
             "changed_modules" => []
           } = Coverage.diff(snapshot, snapshot)
  end

  test "runtime keeps only prefixed modules unless ignored" do
    prefixes = ["Elixir.Certitudo."]

    assert Runtime.keep_module?(Certitudo.Coverage, prefixes, [])
    refute Runtime.keep_module?(Mix.Tasks.Certitudo, prefixes, [])

    refute Runtime.keep_module?(Certitudo.Coverage, prefixes, [
             Certitudo.Coverage
           ])
  end

  test "runtime ignores module matching a regex" do
    prefixes = ["Elixir.Certitudo."]
    refute Runtime.keep_module?(Certitudo.Coverage, prefixes, [~r/Coverage/])
  end

  test "runtime ignores module matching a binary string" do
    prefixes = ["Elixir.Certitudo."]

    refute Runtime.keep_module?(Certitudo.Coverage, prefixes, [
             "Certitudo.Coverage"
           ])
  end

  test "runtime ignores unknown ignore entry type" do
    prefixes = ["Elixir.Certitudo."]
    assert Runtime.keep_module?(Certitudo.Coverage, prefixes, [42])
  end

  test "resolve_prefixes prefers explicit prefixes passthrough when no --prefix is given" do
    opts = [prefixes: ["Elixir.Target."]]

    assert Coverage.resolve_prefixes(opts) == ["Elixir.Target."]
  end

  test "resolve_prefixes prefers CLI --prefix over explicit prefixes passthrough" do
    opts = [prefixes: ["Elixir.Target."], prefix: "Elixir.Override."]

    assert Coverage.resolve_prefixes(opts) == ["Elixir.Override."]
  end

  test "snapshot requires explicit beam_dirs passthrough" do
    assert_raise KeyError, fn ->
      Coverage.snapshot(%{
        coverdata_path: "cover/missing.coverdata",
        opts: [prefixes: ["Elixir.Target."], ignore_modules: []]
      })
    end
  end

  test "snapshot requires explicit ignore_modules passthrough" do
    assert_raise KeyError, fn ->
      Coverage.snapshot(%{
        coverdata_path: "cover/missing.coverdata",
        opts: [prefixes: ["Elixir.Target."], beam_dirs: ["/tmp/ebin"]]
      })
    end
  end

  test "create_snapshot_from_coverdata requires explicit target context" do
    assert_raise KeyError, fn ->
      Coverage.create_snapshot_from_coverdata("cover/missing.coverdata", [])
    end
  end

  test "diff reports source-only changes" do
    left = %{
      "run" => %{"id" => "left"},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{"10" => line_entry(1, "same")},
            source_sha256: "left"
          )
      }
    }

    right = %{
      "run" => %{"id" => "right"},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{"10" => line_entry(1, "same")},
            source_sha256: "right"
          )
      }
    }

    assert %{
             "summary" => %{"changed" => 1},
             "changed_modules" => [
               %{
                 "module" => "Elixir.Certitudo.A",
                 "source_changed" => true,
                 "block_diffs" => [%{"status" => "unchanged"}]
               }
             ]
           } = Coverage.diff(left, right)
  end

  test "diff reports block movement without line transition noise" do
    left = %{
      "run" => %{"id" => "left"},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{
            "10" => line_entry(1, "def foobar(arg) do"),
            "11" => line_entry(1, "bar(arg)")
          })
      }
    }

    right = %{
      "run" => %{"id" => "right"},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{
            "12" => line_entry(1, "def foobar(arg) do"),
            "13" => line_entry(1, "bar(arg)")
          })
      }
    }

    assert %{
             "changed_modules" => [
               %{
                 "block_diffs" => [
                   %{
                     "status" => "moved_unchanged",
                     "left" => %{"range" => %{"first" => 10, "last" => 11}},
                     "right" => %{"range" => %{"first" => 12, "last" => 13}}
                   }
                 ]
               }
             ]
           } = Coverage.diff(left, right)
  end

  test "fingerprint ignores run metadata" do
    left = snapshot_for_fingerprint("left", "2026-06-05T18:00:00Z")
    right = snapshot_for_fingerprint("right", "2026-06-05T19:00:00Z")

    assert Coverage.fingerprint(left) == Coverage.fingerprint(right)
  end

  test "fingerprint changes with stable snapshot body" do
    left = snapshot_for_fingerprint("same", "2026-06-05T18:00:00Z")

    right =
      put_in(
        left,
        ["modules", "Elixir.Certitudo.A", "lines", "10", "covered"],
        false
      )

    assert Coverage.fingerprint(left) != Coverage.fingerprint(right)
  end

  test "write_snapshot and read_snapshot roundtrip snapshot json" do
    snapshot = %{
      "schema_version" => 2,
      "run" => %{"id" => "roundtrip"},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{"10" => line_entry(1, "same")})
      }
    }

    run_dir = tmp_path("roundtrip")

    assert Path.join(run_dir, "snapshot.json") ==
             Coverage.write_snapshot(snapshot, run_dir)

    assert snapshot ==
             Coverage.read_snapshot(Path.join(run_dir, "snapshot.json"))
  end

  test "resolve_snapshot_path accepts direct file and run dir" do
    run_id = "coverage-test-#{System.unique_integer([:positive])}"
    run_dir = tmp_path(run_id)
    snapshot_path = Path.join(run_dir, "snapshot.json")

    snapshot = %{
      "schema_version" => 2,
      "run" => %{"id" => run_id, "label" => "test"},
      "modules" => %{}
    }

    Coverage.write_snapshot(snapshot, run_dir)

    assert Coverage.resolve_snapshot_path(snapshot_path) == snapshot_path
    assert Coverage.resolve_snapshot_path(run_dir) == snapshot_path
  end

  test "resolve_snapshot_path accepts run id under cover" do
    run_id = "coverage-test-#{System.unique_integer([:positive])}"
    run_dir = Path.join(".certitudo", run_id)
    snapshot_path = Path.join(run_dir, "snapshot.json")

    snapshot = %{
      "schema_version" => 2,
      "run" => %{"id" => run_id, "label" => "test"},
      "modules" => %{}
    }

    Coverage.write_snapshot(snapshot, run_dir)

    assert Coverage.resolve_snapshot_path(run_id) == snapshot_path
  end

  test "resolve_snapshot_path raises for unknown path" do
    missing = "missing-#{System.unique_integer([:positive])}"

    assert_raise ArgumentError,
                 "Cannot resolve snapshot path from #{inspect(missing)}",
                 fn -> Coverage.resolve_snapshot_path(missing) end
  end

  test "certitudo_dir is .certitudo" do
    assert Coverage.certitudo_dir() == ".certitudo"
  end

  test "timestamp_id returns a datetime string matching YYYYMMDDTHHMMSSz" do
    assert Regex.match?(~r/^\d{8}T\d{6}Z$/, Coverage.timestamp_id())
  end

  test "find_snapshot_path returns direct file path" do
    path = write_snapshot(%{"run" => %{"id" => "find-test"}})
    assert Coverage.find_snapshot_path(path) == path
  end

  test "find_snapshot_path returns snapshot.json inside a directory" do
    run_dir =
      Path.join(
        System.tmp_dir!(),
        "find-dir-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(run_dir)
    snap = Path.join(run_dir, "snapshot.json")
    File.write!(snap, "{}")
    assert Coverage.find_snapshot_path(run_dir) == snap
  end

  test "find_snapshot_path returns nil for unknown path" do
    assert Coverage.find_snapshot_path("does-not-exist-xyz") == nil
  end

  test "unique_run_dir returns base path when directory does not exist" do
    run_id = "unique-new-#{System.unique_integer([:positive])}"
    base = Path.join(".certitudo", run_id)
    refute File.exists?(base)
    assert Coverage.unique_run_dir(run_id) == base
  end

  test "unique_run_dir returns suffixed path when base exists" do
    run_id = "unique-#{System.unique_integer([:positive])}"
    base = Path.join(".certitudo", run_id)

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    assert Coverage.unique_run_dir(run_id) == "#{base}-1"
  end

  test "unique_run_dir skips to next suffix when base and base-1 both exist" do
    run_id = "unique-#{System.unique_integer([:positive])}"
    base = Path.join(".certitudo", run_id)

    File.mkdir_p!(base)
    File.mkdir_p!("#{base}-1")
    on_exit(fn -> File.rm_rf!(base) && File.rm_rf!("#{base}-1") end)

    assert Coverage.unique_run_dir(run_id) == "#{base}-2"
  end

  defp module_entry(lines, opts \\ []) do
    covered_lines =
      Enum.count(lines, fn {_line, data} -> data["covered"] end)

    executable_lines = map_size(lines)

    %{
      "coverage_percent" => 50.0,
      "covered_lines" => covered_lines,
      "executable_lines" => executable_lines,
      "source" => nil,
      "source_sha256" => Keyword.get(opts, :source_sha256, "sha"),
      "source_size" => Keyword.get(opts, :source_size, 10),
      "lines" => lines
    }
  end

  defp line_entry(calls, text) do
    %{
      "calls" => calls,
      "covered" => calls > 0,
      "text" => text
    }
  end

  defp snapshot_for_fingerprint(run_id, generated_at) do
    %{
      "schema_version" => 2,
      "generated_at" => generated_at,
      "run" => %{
        "id" => run_id,
        "label" => "coverage",
        "coverdata_path" => "cover/export_#{run_id}.coverdata"
      },
      "filter" => %{
        "prefixes" => ["Elixir.Certitudo."],
        "ignore_modules" => []
      },
      "totals" => %{"modules" => 1, "coverage_percent" => 100.0},
      "modules" => %{
        "Elixir.Certitudo.A" =>
          module_entry(%{"10" => line_entry(1, "same")})
      }
    }
  end

  defp write_snapshot(data) do
    path =
      Path.join(
        System.tmp_dir!(),
        "snap-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, Jason.encode!(data))
    path
  end

  defp tmp_path(name) do
    Path.join([
      System.tmp_dir!(),
      "ex-cover-ex-#{name}-#{System.unique_integer([:positive])}"
    ])
  end
end
