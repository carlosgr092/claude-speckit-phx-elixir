# AGENTS.md — contributor conventions for this repo

Coding conventions for anyone (human or agent) editing `claude-speckit-phx-elixir`. This
is the plugin's own contributor guide — not the AGENTS.md block the plugin installs into a
user's project (that lives in `templates/agents-md-block.md`). For the what and why of the
project, read the [README](README.md); for the fused architecture, read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

Golden rule: match what is already there. This is a fusion of two upstreams held together
by strict, uniform conventions. Consistency is the feature.

## The `/spx` namespace rule (non-negotiable)

Every command surface — lifecycle command or capability skill — is namespaced `/spx:`.

- Every command file (`commands/*.md`) and every invocable workflow skill
  (`skills/*/SKILL.md`) carries frontmatter `name: spx:<cmd>`.
- All in-body references to commands use `/spx:<cmd>` — never `/phx:`, never `/speckit`,
  never `/ecto:` or `/lv:`. The upstreams used those prefixes; every ported reference must
  be rewritten.
- Hook messages, agent prompts, handoffs, and skill routing tables all point at `/spx:*`.

A leftover `/phx:`, `/speckit`, or `.claude/plans/` reference is a bug. The consistency
sweep (BLUEPRINT task 52) greps for exactly these and must return zero hits.

## Straight quotes only

Use straight quotes `"` and `'` everywhere — in Markdown, frontmatter, code, hook
messages, `data-confirm`, titles, everything. **Never** use angle quotes `«»`, and avoid
curly/smart quotes `“” ‘’`. This is a hard project rule (D13) and is also seeded in the
constitution's style section. When a body of ported text contains angle or smart quotes,
convert them.

## Markdown conventions

Markdown must pass `markdownlint` against `.markdownlint.json`. That config turns off line
length (`MD013`), allows inline HTML (`MD033`), does not require a top-level H1
(`MD041`), scopes duplicate-heading checks to siblings (`MD024`), sets list indent to 2
spaces (`MD007`), relaxes ordered-list numbering (`MD029`), and disables two rules that
fight intentional patterns — fence-style consistency (`MD048`, for the `~~~` wrappers that
quote fenced examples) and unused-reference detection (`MD053`, for `[PLACEHOLDER]` tokens
in templates). What still bites:

- Increment headings by one level at a time (`MD001`); do not skip from `##` to `####`.
- Surround headings, lists, and fenced code blocks with blank lines
  (`MD022`/`MD031`/`MD032`).
- Every fenced code block gets a language (` ```bash `, ` ```text `, ` ```json `,
  ` ```mermaid `). Use `text` for trees and plain output.
- No trailing whitespace; end files with a single newline; keep list markers consistent
  within a list.
- Prefer tables for catalogs and mappings — they are the house style throughout
  the README and the `docs/` folder.

## Frontmatter conventions

All three surfaces use YAML frontmatter delimited by `---`. Keep keys lowercase-hyphenated
and quote descriptions that contain colons or commas.

### Commands (`commands/*.md`)

```yaml
---
name: spx:specify
description: One sentence, present tense, says what it does and when to use it.
argument-hint: "<feature description> [--lean]"
handoffs:
  - label: Build Technical Plan
    agent: spx:plan
    prompt: Create a plan for the spec. I am building with...
---
```

`name` and `description` are required; `argument-hint` whenever the command takes
arguments; `handoffs` on spine commands to suggest the next phase. Inline any Pre/Post
hook steps from `templates/extensions.yml` as ordered steps in the body. Invoke scripts as
`${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh`.

### Skills (`skills/*/SKILL.md`)

Two flavors. Domain/infrastructure skills auto-load by path and are usually not directly
invocable:

```yaml
---
name: ecto-patterns
description: "Ecto patterns — ... Use when editing Repo calls, Ecto.Query, or schema fields."
effort: medium
user-invocable: false
paths:
  - "**/migrations/*.exs"
  - "**/*_schema.ex"
---
```

Workflow-command skills are invocable and namespaced:

```yaml
---
name: spx:review
description: One sentence — what it does and when to use it.
effort: high
argument-hint: "[test|security|oban|deploy|iron-laws|all]"
---
```

Reference bundled files as `${CLAUDE_SKILL_DIR}/references/<file>.md`. Ship
`references/`, `scripts/`, and `priv/` inside the skill dir; do not scatter them.

### Agents (`agents/*.md`)

Preserve the full frontmatter contract — it encodes the model economics (D12) and the
read-only safety guarantees:

```yaml
---
name: elixir-reviewer
description: One sentence; add "Use proactively after ..." when relevant.
tools: Read, Grep, Glob, Write
disallowedTools: Edit, NotebookEdit
permissionMode: bypassPermissions
model: sonnet
effort: medium
omitClaudeMd: true
skills:
  - elixir-idioms
---
```

- `model`/`effort`: haiku for cheap workers (context-supervisor, verification-runner,
  web-researcher, codex-reviewer, xref-analyzer); opus only for parallel-reviewer,
  security-analyzer, full-driver; sonnet everywhere else.
- Read-only reviewers MUST keep `disallowedTools: Edit, NotebookEdit` and `omitClaudeMd:
  true`. Do not give a reviewer edit tools.
- Every `skills:` entry must resolve to a skill that ships in `skills/`.
- Agent output is written to a file under the feature dir
  (`specs/<feature>/{research,reviews,summaries}/`), never dumped raw into chat.
  Orchestrators fan out in one message and read the files back; nesting depth stays <= 5.

## Shell style (scripts and hooks)

- `#!/usr/bin/env bash` shebang; a leading comment block stating the script's purpose and,
  for ported scripts, its upstream source and the merged deltas (see `scripts/common.sh`
  for the template).
- Parse hook input with `jq` from stdin; quote every expansion (`"$var"`); use `local` in
  functions. Keep the `%q` quoting, parse-success parser chains, and `SPECIFY_INIT_DIR`
  strictness that came from spec-kit.
- Every Elixir-specific hook self-gates on `mix.exs` first (D9):
  `proj="${CLAUDE_PROJECT_DIR:-$PWD}"; [ -f "$proj/mix.exs" ] || exit 0`. The generic
  spine (git, dangerous-ops) does not gate.
- Honor each hook event's output contract (BLUEPRINT section 6): PostToolUse uses
  `exit 2` + stderr; UserPromptSubmit never exits 2; `block-dangerous-ops.sh` stays
  fail-open (`|| exit 0`) and denies via JSON `permissionDecision:"deny"` + exit 0.
- Spine scripts emit `--json` output and reference the plugin root via
  `${CLAUDE_PLUGIN_ROOT}`. Keep all `*.sh` executable (`chmod +x`).
- `hooks.json` must parse with `jq .`; wire scripts through `${CLAUDE_PLUGIN_ROOT}` with
  the right `matcher`/`if`/`timeout`.

## Ported files stay faithful to upstream

Most of this repo is ported from `github/spec-kit` or `claude-elixir-phoenix`. When you
port or edit a ported file:

- Change only what the fusion requires: the `/spx` namespace, the `specs/<feature>/` paths
  (D2), straight quotes, and the specific `<!-- ELIXIR-PHOENIX ... -->` fusion blocks. Preserve
  upstream logic, structure, wording, and safety contracts verbatim otherwise.
- Contracts that must survive byte-for-byte: the URL Trust
  Policy in `assess`/`bug`, the hook output contracts, the block-dangerous-ops fail-open
  behavior, the P1-P3 review rubric's "Known non-issues", and the model tiers.
- Note the upstream source and any deltas in the file's header comment.
- The `iron-law-verifier.sh`, `inject-iron-laws.sh`, `agents-md-block.md`, and
  `claude-md-block.md` are DERIVED from `memory/constitution.md` — never hand-edit them to
  change a rule; edit the constitution and regenerate (see `memory/derivations.md`).

## Attribution

This is a derivative work. `NOTICE.md` and the README must credit both upstreams (MIT), and
`LICENSE` (MIT) stays in place. Do not remove or weaken attribution. Do not add Claude
co-authorship trailers to commits or PRs.

## Before you commit

Run `make ci` (markdownlint + yamllint + jq over JSON + hook tests + `claude plugin
validate .`) and the BLUEPRINT task 52 consistency sweep. Green means: zero stale
namespace/path references, every `skills:` target and `${CLAUDE_*}` path resolves,
`hooks.json` parses, and every `*.sh` is executable.
