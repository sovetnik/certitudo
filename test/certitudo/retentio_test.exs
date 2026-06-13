defmodule Certitudo.RetentioTest do
  use ExUnit.Case, async: false

  alias Certitudo.Retentio

  test "find with no opts returns previous snapshot" do
    prev_dir = write_valid_snapshot(unique_run_id())
    on_exit(fn -> File.rm_rf!(prev_dir) end)

    result = Retentio.find(certitudo_path(unique_run_id()))
    assert is_binary(result)
  end

  test "resolve returns skipped when auto_diff is disabled" do
    assert Retentio.resolve(
             [auto_diff: false],
             certitudo_path(unique_run_id()),
             certitudo_path(unique_run_id())
           ) ==
             :skipped
  end

  test "resolve returns since_not_found when explicit since target does not exist" do
    assert Retentio.resolve(
             [since: "missing-snapshot", auto_diff: true],
             certitudo_path(unique_run_id()),
             certitudo_path(unique_run_id())
           ) == {:since_not_found, "missing-snapshot"}
  end

  test "resolve returns ok tuple when previous snapshot exists" do
    prev_id = unique_run_id()
    prev_dir = write_valid_snapshot(prev_id)
    on_exit(fn -> File.rm_rf!(prev_dir) end)

    result =
      Retentio.resolve(
        [auto_diff: true],
        certitudo_path(unique_run_id()),
        certitudo_path(unique_run_id())
      )

    assert result == {:ok, Path.join(prev_dir, "snapshot.json")}
  end

  test "find with since opt resolves a direct file path" do
    path = write_tmp_snapshot()

    assert Retentio.find(certitudo_path(unique_run_id()), since: path) ==
             path
  end

  test "find with unknown since returns nil" do
    assert Retentio.find(certitudo_path(unique_run_id()),
             since: "nonexistent-xyz"
           ) == nil
  end

  test "previous excludes current run dir" do
    run_id = unique_run_id()
    run_dir = certitudo_path(run_id)
    snap = Path.join(run_dir, "snapshot.json")

    write_valid_snapshot(run_id)
    on_exit(fn -> File.rm_rf!(run_dir) end)

    result = Retentio.previous(run_dir)
    refute result == snap
  end

  test "previous returns most recently modified valid snapshot" do
    older_id = unique_run_id()
    newer_id = unique_run_id()

    older_dir = write_valid_snapshot(older_id)
    newer_dir = write_valid_snapshot(newer_id)

    File.touch!(
      Path.join(newer_dir, "snapshot.json"),
      {{2099, 1, 1}, {0, 0, 0}}
    )

    on_exit(fn ->
      File.rm_rf!(older_dir)
      File.rm_rf!(newer_dir)
    end)

    result = Retentio.previous(certitudo_path(unique_run_id()))
    assert result == Path.join(newer_dir, "snapshot.json")
  end

  test "previous for a new run keeps the latest existing snapshot even if an older duplicate exists" do
    duplicate_id = unique_run_id()
    latest_id = unique_run_id()

    duplicate_dir = write_valid_snapshot(duplicate_id)
    latest_dir = write_valid_snapshot(latest_id)

    File.touch!(
      Path.join(latest_dir, "snapshot.json"),
      {{2099, 1, 1}, {0, 0, 0}}
    )

    on_exit(fn ->
      File.rm_rf!(duplicate_dir)
      File.rm_rf!(latest_dir)
    end)

    result = Retentio.previous(certitudo_path(unique_run_id()))
    assert result == Path.join(latest_dir, "snapshot.json")
  end

  test "previous can exclude a reused impressio run dir during deja vu" do
    duplicate_id = unique_run_id()
    previous_id = unique_run_id()

    duplicate_dir = write_valid_snapshot(duplicate_id)
    previous_dir = write_valid_snapshot(previous_id)

    File.touch!(
      Path.join(duplicate_dir, "snapshot.json"),
      {{2099, 1, 2}, {0, 0, 0}}
    )

    File.touch!(
      Path.join(previous_dir, "snapshot.json"),
      {{2099, 1, 1}, {0, 0, 0}}
    )

    on_exit(fn ->
      File.rm_rf!(duplicate_dir)
      File.rm_rf!(previous_dir)
    end)

    result =
      Retentio.previous(certitudo_path(unique_run_id()), [duplicate_dir])

    assert result == Path.join(previous_dir, "snapshot.json")
  end

  test "previous skips invalid snapshot files" do
    bad_id = unique_run_id()
    bad_dir = certitudo_path(bad_id)
    File.mkdir_p!(bad_dir)
    File.write!(Path.join(bad_dir, "snapshot.json"), "not json")
    on_exit(fn -> File.rm_rf!(bad_dir) end)

    result = Retentio.previous(bad_dir)
    refute result == Path.join(bad_dir, "snapshot.json")
  end

  defp unique_run_id,
    do: "retentio-test-#{System.unique_integer([:positive])}"

  defp certitudo_path(run_id), do: Path.join(".certitudo", run_id)

  defp write_valid_snapshot(run_id) do
    dir = certitudo_path(run_id)
    File.mkdir_p!(dir)

    snapshot = %{
      "schema_version" => 2,
      "run" => %{
        "id" => run_id,
        "label" => "test",
        "coverdata_path" => "cover/x.coverdata"
      },
      "modules" => %{}
    }

    File.write!(Path.join(dir, "snapshot.json"), Jason.encode!(snapshot))
    dir
  end

  defp write_tmp_snapshot do
    path =
      Path.join(
        System.tmp_dir!(),
        "retentio-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, Jason.encode!(%{"run" => %{"id" => "tmp"}}))
    path
  end
end
