defmodule Certitudo.Report.StoreTest do
  use ExUnit.Case, async: true

  alias Certitudo.Report.Store

  test "snapshot_path! returns :snapshot option directly" do
    assert Store.snapshot_path!(snapshot: "/tmp/snap.json") ==
             "/tmp/snap.json"
  end

  test "snapshot_path! builds path from :run id" do
    expected =
      Path.join([
        Certitudo.Coverage.certitudo_dir(),
        "20260606T120000Z",
        "snapshot.json"
      ])

    assert Store.snapshot_path!(run: "20260606T120000Z") == expected
  end

  test "snapshot_path! with no opts returns latest snapshot path" do
    run_id = "store-test-#{System.unique_integer([:positive])}"
    dir = Path.join(Certitudo.Coverage.certitudo_dir(), run_id)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "snapshot.json"), Jason.encode!(%{}))
    File.write!(Path.join(dir, "coverage.coverdata"), "")

    on_exit(fn -> File.rm_rf!(dir) end)

    path = Store.snapshot_path!([])
    assert is_binary(path)
    assert String.ends_with?(path, "snapshot.json")
    assert File.regular?(path)
  end

  test "find_module returns exact match with Elixir prefix" do
    modules = %{"Elixir.Certitudo.Coverage" => %{}}

    assert {:ok, "Elixir.Certitudo.Coverage"} =
             Store.find_module(modules, "Certitudo.Coverage")
  end

  test "find_module accepts query already prefixed with Elixir." do
    modules = %{"Elixir.Certitudo.Coverage" => %{}}

    assert {:ok, "Elixir.Certitudo.Coverage"} =
             Store.find_module(modules, "Elixir.Certitudo.Coverage")
  end

  test "find_module returns unique suffix match" do
    modules = %{"Elixir.Certitudo.Coverage" => %{}}

    assert {:ok, "Elixir.Certitudo.Coverage"} =
             Store.find_module(modules, "Coverage")
  end

  test "find_module returns :not_found for missing module" do
    assert {:error, :not_found} = Store.find_module(%{}, "Missing")
  end

  test "find_module returns ambiguous for multiple suffix matches" do
    modules = %{
      "Elixir.Certitudo.Coverage" => %{},
      "Elixir.Certitudo.Coverage.Runtime" => %{}
    }

    assert {:error, {:ambiguous, matches}} =
             Store.find_module(modules, "Coverage")

    assert length(matches) == 2
  end

  test "demodulize strips Elixir prefix" do
    assert Store.demodulize("Elixir.Certitudo.Coverage") ==
             "Certitudo.Coverage"
  end

  test "demodulize returns name unchanged without prefix" do
    assert Store.demodulize("Certitudo.Coverage") == "Certitudo.Coverage"
  end

  test "read_snapshot! reads and decodes JSON" do
    path = write_tmp(%{"key" => "value"})
    assert %{"key" => "value"} = Store.read_snapshot!(path)
  end

  defp write_tmp(data) do
    path =
      Path.join(
        System.tmp_dir!(),
        "store-test-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, Jason.encode!(data))
    path
  end
end
