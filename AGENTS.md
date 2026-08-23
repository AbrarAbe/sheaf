<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **taker** (340 symbols, 387 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/taker/context` | Codebase overview, check index freshness |
| `gitnexus://repo/taker/clusters` | All functional areas |
| `gitnexus://repo/taker/processes` | All execution flows |
| `gitnexus://repo/taker/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

# Development Workflow

Work follows the installed agent skills. Do not improvise process — invoke the
skill and follow it.

## Task pipeline

1. **Spec first** — no feature starts without a spec (`spec-driven-development`).
   The living spec lives at `docs/spec.md`; update it before changing behavior.
2. **Plan into tasks** — break approved specs into ordered, verifiable tasks in
   `docs/plan.md` (`planning-and-task-breakdown`). Tick tasks off as they land.
3. **Implement incrementally** — one plan task at a time, red→green
   (`incremental-implementation` + `test-driven-development`). Never call a task
   done with failing or skipped tests.
4. **Test strategy** — consult `testing-strategy` when scope is unclear; use
   `dart-add-unit-test`, `dart-generate-test-mocks`, `flutter-add-widget-test`,
   and `flutter-add-integration-test` for the mechanics.
5. **Document decisions** — non-obvious architectural choices get an ADR under
   `docs/adr/` (`documentation-and-adrs`).
6. **Commit after every completed task** — see Commit discipline below.

## Definition of done (per task)

- [ ] Acceptance criteria from `docs/plan.md` met
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (new tests included, failing-first where practical)
- [ ] Hot reload pushed to any running app (rule below)
- [ ] Committed with a semantic message

## Commit discipline

- One commit per completed task — never bundle unrelated tasks.
- Messages follow the `commit-message` skill: Conventional Commits style
  (`type(scope): summary`), summary ≤ 72 chars, blank line, body explaining
  what/why for anything non-trivial. Reference issue numbers when applicable.
  Examples:
  - `feat(theme): add Quire Daylight/Lamplight token themes`
  - `test(vault): cover trash restore round-trip (#12)`
- Verify scope before committing (`git --no-pager diff --stat`); only files the
  task touched belong in the commit.

Whenever you make edits to any Dart or Flutter files in this project:
1. Proactively connect to the running application using the `dtd` tool and its subcommands. Make sure to read the schema for this tool.
2. Trigger a hot reload using the `hot_reload` tool to push the changes immediately.
3. If no app is running, inform the user but do not let it stop you from completing the code edits.
