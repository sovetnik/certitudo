defmodule Certitudo.DiscordiaTest do
  use ExUnit.Case, async: false

  alias Certitudo.Discordia

  test "comparare reads both snapshots and returns the differentia" do
    retentio_path =
      write_snapshot("retentio", %{
        "Elixir.Certitudo.A" => module_entry(false)
      })

    impressio_path =
      write_snapshot("impressio", %{
        "Elixir.Certitudo.A" => module_entry(true)
      })

    on_exit(fn ->
      File.rm_rf!(Path.dirname(retentio_path))
      File.rm_rf!(Path.dirname(impressio_path))
    end)

    diff = Discordia.comparare(retentio_path, impressio_path)

    assert %{
             "summary" => %{"changed" => 1},
             "changed_modules" => [%{"module" => "Elixir.Certitudo.A"}]
           } = diff
  end

  test "inferentia writes diff.prev.json into impressio_run_dir when retentio found" do
    retentio_path =
      write_snapshot("retentio", %{
        "Elixir.Certitudo.A" => module_entry(false)
      })

    impressio_run_dir =
      Path.dirname(
        write_snapshot("impressio", %{
          "Elixir.Certitudo.A" => module_entry(true)
        })
      )

    on_exit(fn ->
      File.rm_rf!(Path.dirname(retentio_path))
      File.rm_rf!(impressio_run_dir)
    end)

    ctx = %{
      retentio: {:ok, retentio_path},
      impressio_run_dir: impressio_run_dir
    }

    result = Discordia.inferentia(ctx)

    diff_path = Path.join(impressio_run_dir, "diff.prev.json")
    assert File.regular?(diff_path)

    assert {:ok,
            %{
              retentio_path: ^retentio_path,
              diff: diff,
              diff_path: ^diff_path
            }} = result.diff

    assert %{"summary" => %{"changed" => 1}} = diff
  end

  test "inferentia passes through when retentio was not found" do
    assert Discordia.inferentia(%{retentio: :skipped}) ==
             %{retentio: :skipped, diff: :skipped}

    assert Discordia.inferentia(%{retentio: {:since_not_found, "missing"}}) ==
             %{
               retentio: {:since_not_found, "missing"},
               diff: {:since_not_found, "missing"}
             }
  end

  defp write_snapshot(label, modules) do
    run_id = "discordia-test-#{label}-#{System.unique_integer([:positive])}"
    dir = Path.join(".certitudo", run_id)
    File.mkdir_p!(dir)

    snapshot = %{
      "schema_version" => 2,
      "run" => %{
        "id" => run_id,
        "label" => label,
        "coverdata_path" => "cover/x.coverdata"
      },
      "modules" => modules
    }

    path = Path.join(dir, "snapshot.json")
    File.write!(path, Jason.encode!(snapshot))
    path
  end

  defp module_entry(line_11_covered?) do
    calls = if line_11_covered?, do: 1, else: 0

    %{
      "coverage_percent" => 50.0,
      "covered_lines" => 1 + calls,
      "executable_lines" => 2,
      "source_sha256" => "sha",
      "source_size" => 10,
      "lines" => %{
        "10" => %{"calls" => 1, "covered" => true, "text" => "same"},
        "11" => %{
          "calls" => calls,
          "covered" => line_11_covered?,
          "text" => "changed"
        }
      }
    }
  end
end
