# Certitudo — Agent Contract

This file is for machine spirits operating `certitudo`.
It does not replace `README.md`; it fixes the operational contract for agents.

## Primary mode

- Prefer `mix certitudo --no-color`.
- Use `mix certitudo --example --no-color` when you need to inspect the full
  rendering vocabulary without generating a real snapshot.
- Use `--since <run_id_or_snapshot>` when the comparison base must be explicit.
- If no explicit `--since` is given, `certitudo` compares against the latest valid prior snapshot.

## How to read the output

Treat the textual status as the primary interface.
Color may be absent; the status words remain authoritative.

- `new_covered`, `existing_coverage_gained`: coverage improved.
- `new_uncovered`: new executable code appeared without coverage.
- `existing_coverage_lost`: previously covered code lost coverage.
- `existing_coverage_mixed`: the same block contains both gains and losses.
- `moved_unchanged`: code moved, but coverage meaning stayed stable.
- `ambiguous_moved`: block identity is unclear; do not over-interpret.
- `Identical: coverage not changed`: no coverage delta against the chosen retentio.

`Certitudo: X% for N modules` is a summary, not the decision.
The decision should come from the block-level statuses above it.

## When a new test is needed

Assume a new test is required when one of these is true:

- `new_uncovered` appears in logic that was added intentionally.
- `existing_coverage_lost` appears in code that still exists semantically after the change.
- `existing_coverage_mixed` appears and the lost side is not explained by pure movement or dead-code removal.

Do not demand a new test solely because:

- `moved_unchanged` appears;
- uncovered code was removed (`removed_uncovered`);
- covered code was removed entirely as intentional deletion, and the removed behavior no longer exists.

When in doubt, ask: does executable behavior still exist on the right side without protection?
If yes, a new or updated test is probably needed.

## Looking at poor coverage

To inspect one module quickly:

```bash
mix certitudo.speculum "MyApp.SomeModule"
mix certitudo.speculum "SomeModule" --run <run_id>
```

To inspect uncovered executable lines:

```bash
mix certitudo.lacunae "MyApp.SomeModule"
mix certitudo.lacunae "SomeModule" --run <run_id>
mix certitudo.lacunae "SomeModule" --snapshot .certitudo/<run_id>/snapshot.json
mix certitudo.lacunae "SomeModule" --force
```

`lacunae` is module-oriented, not path-oriented.
If you start from a file, first identify the module defined in that file, then query that module.

If the snapshot may be stale relative to current beam files, either:

- run `mix certitudo` again, or
- use `mix certitudo.lacunae ... --force`

`--force` rebuilds the selected snapshot from its saved `coverdata` and saved
target project context. It is a refresh of one snapshot view, not a new run.

## Limits

- `mix certitudo` is the human and agent-facing orchestration command.
- `Certitudo.obducere/2` is lower-level and requires explicit target context from the caller.
- Do not assume library calls can infer project context from the current host runtime.
- `mix certitudo.inspectio` reasons in report runs; when it prompts, the threshold is report-count based, not raw file-count based.
