# Contributing to claude-speckit-phx-elixir

Thanks for your interest in improving **claude-speckit-phx-elixir** — a Claude Code plugin that fuses the [Spec Kit](https://github.com/github/spec-kit) spec-driven flow with the [claude-elixir-phoenix](https://github.com/oliver-kriska/claude-elixir-phoenix) knowledge base for Elixir/Phoenix. Contributions are released to the public under the [project's MIT license](LICENSE).

Please note this project ships with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating you agree to abide by its terms.

## Table of contents

- [This is a derivative work — read this first](#this-is-a-derivative-work--read-this-first)
- [The constitution is the single source of truth](#the-constitution-is-the-single-source-of-truth)
- [Development setup](#development-setup)
- [What you can contribute](#what-you-can-contribute)
  - [Skills](#skills)
  - [Agents](#agents)
  - [Hooks](#hooks)
  - [Commands](#commands)
  - [Scripts and templates](#scripts-and-templates)
- [Local checks before you open a PR](#local-checks-before-you-open-a-pr)
- [Branch naming](#branch-naming)
- [The pull request flow](#the-pull-request-flow)
- [Releases](#releases)
- [Disclosing AI assistance](#disclosing-ai-assistance)
- [Resources](#resources)

## This is a derivative work — read this first

This plugin is a fusion of two MIT-licensed upstreams (see [`NOTICE.md`](NOTICE.md)):

| Upstream | What we derive from it |
|---|---|
| [github/spec-kit](https://github.com/github/spec-kit) | the spec-driven flow, command surfaces, artifact templates (spec/plan/tasks/checklist/constitution), and the `scripts/` automation |
| [oliver-kriska/claude-elixir-phoenix](https://github.com/oliver-kriska/claude-elixir-phoenix) | the 26 specialist agents, the Elixir/Phoenix/Ecto/LiveView/Oban/Ash/OTP skills and references, the enforcement hooks, and the Iron Laws corpus |

Because so much of the plugin is **ported from upstream**, one rule matters above all:

> **If a change would be equally correct in the upstream project, send it upstream first.**

A bug fix or improvement to a ported agent, skill, hook, or template that is not specific to our fusion belongs in `github/spec-kit` or `claude-elixir-phoenix`. We then pull the corrected version down. This keeps the two lineages faithful and avoids divergent forks of the same file. Open an issue here so we can track the upstream PR and the eventual sync.

Changes that **are** in scope for this repo:

- The `/spx:*` command surfaces and how the two flows are wired together.
- The fused constitution (Iron Laws + Articles) and its enforcement.
- Anything that only exists because spec-kit and claude-elixir-phoenix were merged.

## The constitution is the single source of truth

`memory/constitution.md` — 53 Iron Laws across 8 Articles — is the **canonical** governance document for the plugin. It is the single source of truth for every Iron Law and principle.

- **Never edit an Iron Law in a derived copy.** The `/spx:constitution` command regenerates the derived enforcement copies from the canonical file. If you hand-edit a copy, your change is lost on the next regeneration and the copies drift out of sync.
- **Edit the canonical file, then regenerate.** Change `memory/constitution.md`, then let `/spx:constitution` propagate the update into the derived copies, templates, and commands.
- **Bump the constitution version** (semver, with a Sync Impact Report) when you change a law's meaning. Editorial/typo fixes do not need a bump.

If your change touches an Iron Law or an Article, say so explicitly in the PR and include the regenerated diff.

## Development setup

This is a Claude Code plugin — there is no compile step and no package manager to install. You need:

1. [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed.
2. `git` to clone the repo.
3. An Elixir/Phoenix project to exercise the `/spx:*` commands against (most flows assume a `mix.exs`).
4. Optional but recommended for local checks: [`markdownlint-cli2`](https://github.com/DavidAnson/markdownlint-cli2), [`shellcheck`](https://www.shellcheck.net/), and [`jq`](https://jqlang.github.io/jq/).

To develop against your working tree, load the plugin from your local checkout so Claude Code picks up your branch:

```bash
git clone https://github.com/carlosgr092/claude-speckit-phx-elixir
cd claude-speckit-phx-elixir
# Point your Claude Code plugin configuration at this directory, then open an
# Elixir/Phoenix project in another window and run the /spx:* commands you changed.
```

## What you can contribute

The plugin is organized into a few distinct surfaces. Match your change to the right one.

### Skills

Skills live in `skills/<name>/SKILL.md` (plus optional `references/`). A skill is model-facing knowledge that auto-activates on paths or is invoked by a command.

- Keep the `name`, `description`, and trigger metadata accurate — the description is what makes the skill fire at the right moment.
- Most skills are **ported from claude-elixir-phoenix**. If the improvement is not fusion-specific, send it upstream (see [above](#this-is-a-derivative-work--read-this-first)).
- Rewrite any `/phx:*` reference to the matching `/spx:*` command when adapting upstream text.

### Agents

Agents live in `agents/<name>.md` with YAML frontmatter (`name`, `description`, `tools`, `model`). They are the specialists the commands delegate to.

- Preserve the agent's single responsibility. If you are adding behavior, prefer a new agent over overloading an existing one.
- The 26 specialist agents are ported. Upstream-faithful fixes go upstream.

### Hooks

Hooks are declared in `hooks/hooks.json` and implemented in `hooks/scripts/`. They enforce Iron Laws mechanically (formatting, verification gates, plan-stop, etc.).

- A hook runs **shell**. Keep it fast, deterministic, and non-interactive.
- Add or update a test under `hooks/tests/` for any behavioral change.
- Never make a hook that phones home, mutates files outside the project, or blocks on network access.

### Commands

Commands live in `commands/<name>.md` and carry frontmatter `name: spx:<cmd>`. They are the user-facing `/spx:*` surfaces.

- Keep the `/spx:` namespace. Every command surface must carry `name: spx:<cmd>`.
- If a command's behavior changes, exercise it end to end in a real Elixir/Phoenix project and paste the result into your PR (see [manual testing](#the-pull-request-flow)).
- Respect command ordering dependencies (for example, `/spx:tasks` requires `/spx:plan`, which requires `/spx:specify`).

### Scripts and templates

`scripts/` holds the spec-kit-derived automation (feature creation, prerequisite checks, plan/tasks setup, git and agent-context helpers). `templates/` holds the artifact skeletons.

- Shell scripts must pass `shellcheck --severity=error`.
- Template changes ripple into generated artifacts — verify the output of the command that consumes the template.

## Local checks before you open a PR

Run these from the repo root and fix anything they flag:

```bash
# Markdown must pass markdownlint (config: .markdownlint.json)
markdownlint-cli2 "**/*.md"

# Shell scripts must be clean at error severity
git ls-files -z -- '*.sh' | xargs -0 shellcheck --severity=error

# JSON config must parse (plugin.json, hooks.json, dependabot.yml is YAML)
jq empty .claude-plugin/plugin.json
jq empty hooks/hooks.json

# Hook tests, if your change touched a hook
bash hooks/tests/run.sh   # if present
```

## Branch naming

Name branches `<type>/<number>-<short-slug>`, where `<number>` is the issue or PR number and `<type>` is one of:

| Prefix | When to use | Example |
|---|---|---|
| `feat/` | New features | `feat/42-spx-review-gate` |
| `fix/` | Bug fixes | `fix/57-format-hook-crlf` |
| `docs/` | Documentation | `docs/61-readme-badges` |
| `chore/` | Maintenance, tooling, CI | `chore/64-dependabot` |
| `upstream/` | Syncing a fix from an upstream project | `upstream/70-skill-parity` |

Including the issue or PR number keeps branches traceable under squash merges.

## The pull request flow

1. Fork and clone the repository.
2. Create a branch (see [Branch naming](#branch-naming)).
3. Make your change. Keep it focused — unrelated changes belong in separate PRs.
4. Run the [local checks](#local-checks-before-you-open-a-pr).
5. If your change affects a `/spx:*` command's behavior, **test it manually** in a real Elixir/Phoenix project and paste the result:

   ~~~markdown
   ## Manual test results

   **OS/Shell**: [e.g., Arch Linux / zsh]

   | Command tested | Result | Notes |
   |----------------|--------|-------|
   | `/spx:command` | pass | |
   ~~~

6. If your change is an upstream-faithful fix to a ported file, link the upstream PR (see [derivative-work rule](#this-is-a-derivative-work--read-this-first)).
7. Push to your fork and open a pull request against `main`. Fill in the [PR template](.github/PULL_REQUEST_TEMPLATE.md), including the AI-disclosure checkbox.
8. A maintainer reviews and merges. Large or structural changes should be [discussed in an issue](https://github.com/carlosgr092/claude-speckit-phx-elixir/issues) or [Discussion](https://github.com/carlosgr092/claude-speckit-phx-elixir/discussions) first — unsolicited large PRs may be closed.

## Releases

This is a release-based project following [semantic versioning](https://semver.org/) from `v0.1.0` and [Keep a Changelog](https://keepachangelog.com/).

- The version lives in `.claude-plugin/plugin.json` and mirrors the release tag.
- Every user-facing change gets an entry in `CHANGELOG.md` under `Unreleased`.
- Maintainers cut a release by finalizing the changelog, bumping `plugin.json`, tagging `vX.Y.Z`, and creating the GitHub release.

## Disclosing AI assistance

If you used **any** AI assistance to prepare a contribution, disclose it in the PR (the template has a checkbox). State the extent — from "typo fix" to "code fully generated." This is a matter of respect for reviewers and helps calibrate scrutiny. Trivial spacing/typo fixes are exempt. Undisclosed, untested, bulk AI output may be closed.

## Resources

- [Spec-Driven Development (spec-kit)](https://github.com/github/spec-kit)
- [claude-elixir-phoenix](https://github.com/oliver-kriska/claude-elixir-phoenix)
- [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)
- [Using Pull Requests](https://help.github.com/articles/about-pull-requests/)
