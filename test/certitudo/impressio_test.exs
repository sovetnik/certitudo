defmodule Certitudo.ImpressioTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Certitudo.{Coverage, Impressio}

  test "resolve writes new snapshot and returns :new" do
    run_id = unique_run_id()
    run_dir = certitudo_path(run_id)
    on_exit(fn -> File.rm_rf!(run_dir) end)

    snapshot = base_snapshot(run_id)
    coverdata = tmp_coverdata()

    {kind, returned_dir, returned_snapshot} =
      Impressio.resolve(snapshot, run_dir, coverdata)

    assert kind == :new
    assert returned_dir == run_dir
    assert returned_snapshot == snapshot
    assert File.regular?(Path.join(run_dir, "snapshot.json"))
    assert File.regular?(Path.join(run_dir, "coverage.coverdata"))
  end

  test "resolve returns :known when duplicate fingerprint exists" do
    run_id = unique_run_id()
    run_dir = certitudo_path(run_id)
    on_exit(fn -> File.rm_rf!(run_dir) end)

    snapshot =
      base_snapshot(run_id)
      |> Coverage.fingerprint()
      |> then(&Map.put(base_snapshot(run_id), "fingerprint", &1))

    coverdata = tmp_coverdata()

    Coverage.write_snapshot(snapshot, run_dir)

    new_run_id = unique_run_id()
    new_run_dir = certitudo_path(new_run_id)

    {kind, returned_dir, returned_snapshot} =
      Impressio.resolve(snapshot, new_run_dir, coverdata)

    assert kind == :known
    assert returned_dir == run_dir
    assert returned_snapshot == snapshot
    refute File.dir?(new_run_dir)
  end

  test "find_duplicate returns nil when no fingerprint in snapshot" do
    assert Impressio.find_duplicate(%{"modules" => %{}}) == nil
  end

  test "find_duplicate returns nil when no matching fingerprint exists" do
    assert Impressio.find_duplicate(%{
             "fingerprint" => "no-such-fingerprint"
           }) == nil
  end

  test "find_duplicate returns path when fingerprint matches" do
    run_id = unique_run_id()
    run_dir = certitudo_path(run_id)
    on_exit(fn -> File.rm_rf!(run_dir) end)

    snapshot =
      base_snapshot(run_id)
      |> then(&Map.put(&1, "fingerprint", Coverage.fingerprint(&1)))

    Coverage.write_snapshot(snapshot, run_dir)

    result = Impressio.find_duplicate(snapshot)
    assert result == Path.join(run_dir, "snapshot.json")
  end

  test "find_duplicate skips corrupt snapshot files" do
    bad_id = unique_run_id()
    bad_dir = certitudo_path(bad_id)
    File.mkdir_p!(bad_dir)
    File.write!(Path.join(bad_dir, "snapshot.json"), "not json {{")
    on_exit(fn -> File.rm_rf!(bad_dir) end)

    capture_io(:stderr, fn ->
      refute Impressio.find_duplicate(%{"fingerprint" => "any"}) ==
               Path.join(bad_dir, "snapshot.json")
    end)
  end

  defp unique_run_id,
    do: "impressio-test-#{System.unique_integer([:positive])}"

  defp certitudo_path(run_id), do: Path.join(".certitudo", run_id)

  defp base_snapshot(run_id) do
    %{
      "schema_version" => 2,
      "run" => %{
        "id" => run_id,
        "label" => "test",
        "coverdata_path" => "cover/x.coverdata"
      },
      "modules" => %{}
    }
  end

  defp tmp_coverdata do
    path =
      Path.join(
        System.tmp_dir!(),
        "impressio-#{System.unique_integer([:positive])}.coverdata"
      )

    File.write!(path, "")
    path
  end
end
