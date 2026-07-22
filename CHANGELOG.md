# CHANGELOG

## 0.1.2 - 2026-07-22

### Fixed
- `mix certitudo`'s console output no longer prints one `moved_unchanged`
  line per moved block. A refactor that shifts dozens of untouched blocks
  (e.g. inserting a function above existing code) drowned the signal —
  real coverage gains/losses — under a wall of refactor noise. Adjacent
  `moved_unchanged` blocks now collapse into a single
  `moved_unchanged (N): range, range, ...` line; all other statuses are
  unaffected.

## 0.1.1 - 2026-06-25

### Fixed
- `mix certitudo`'s default module scope no longer guesses a string prefix
  from `Macro.camelize(Mix.Project.config()[:app])`. That guess silently
  broke for any project whose `:app` atom doesn't match its top-level
  module name (e.g. an app named `foo_ex` whose modules live under `Foo.*`)
  — the prefix matched zero modules, and `coverage_percent` reported a
  fictitious `100.0%` instead of measuring anything.
- `Certitudo.Coverage.Runtime.own_module_names/1` (new) derives the
  default module scope from the `.beam` files actually compiled into
  `beam_dirs` instead — a filesystem fact, not a naming convention.
  `keep_module?/3` → `/4` and `modules/2` → `/3` thread this through as an
  additive exact-match set, alongside (not replacing) explicit `--prefix`
  matching.
- `Certitudo.Conspectus.Build.totals/1` no longer reports `100.0%` when no
  modules matched the scope at all — that case now reports `nil`
  (`mix certitudo`'s own CLI output prints "coverage not measured (no
  modules matched)" instead of a blank percentage). A module that
  genuinely has zero executable lines still correctly reports `100.0%`,
  unchanged.
- `Certitudo.obducere/2`'s existing contract (explicit `prefixes`/
  `beam_dirs`/`ignore_modules` passthrough) is unchanged; the new
  `own_modules` is optional and defaults to empty for any caller that
  doesn't pass it.
