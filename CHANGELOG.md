# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- CI: the `Validate` workflow's structural-checks fallback enumerated 0
  command/agent/skill files and failed the gate on every push. The `enum` helper
  captured `git ls-files -z` output in a command substitution, which strips NUL
  bytes, so the NUL-delimited reader downstream saw zero files. It now streams the
  NUL list directly and correctly validates 21 commands, 26 agents, and 48 skills.
- Docs: corrected the constitution article count from 8 to 9 across the README,
  CONTRIBUTING, ARCHITECTURE, and CHANGELOG, and added Article IX (the reserved
  project-specific principles slot) to the README's article enumeration. The shipped
  constitution already had 9 Articles; only the prose describing it lagged.

## [0.1.0] - 2026-07-21

Initial fused release. The full spec-kit spec-driven flow, made Elixir-aware end to end
by absorbing the claude-elixir-phoenix intelligence into every phase. One Claude Code
plugin, `/spx:*` commands. This is a derivative work fusing
[github/spec-kit](https://github.com/github/spec-kit) and
[oliver-kriska/claude-elixir-phoenix](https://github.com/oliver-kriska/claude-elixir-phoenix),
both MIT (see [NOTICE.md](NOTICE.md)).

### Added

- **The spec-driven spine (10 commands).** `constitution`, `specify`, `clarify`, `plan`,
  `tasks`, `analyze`, `checklist`, `implement`, `tasks-to-issues`, and `agent-context` —
  the spec-kit lifecycle rewired so absorbed Elixir intelligence fires inside each phase
  (Phoenix-shaped clarify questions, an Elixir/Phoenix Design section in plan, migration-safe
  task ordering, per-task `mix compile --warnings-as-errors` in implement).
- **Git commands (5).** `git-init`, `git-feature`, `git-commit`, `git-validate`,
  `git-remote`, auto-wired into the spine and available standalone.
- **Flow extensions (6).** `converge` (post-implement gap assessment), `full` (autonomous
  driver over the whole chain with cycle caps and optional gates), `assess` (pre-specify
  idea pipeline), `bug` (artifact-based bugfix loop), `init` (idempotent project bootstrap),
  and `doctor` (read-only health check).
- **Capability commands (34).** Review, triage, challenge, quick, verify, investigate,
  trace, n1-check, boundaries, assigns-audit, narrow-bare-rescue, perf, techdebt, audit,
  deps-audit, deps-update, deps-vet, freeze, permissions, mix-compression, research, recall,
  compound, learn, document, brief, brainstorm, help, intro, pr-review, watch-pr, codex-loop,
  deploy, and ecto-constraint-debug.
- **26 specialist subagents.** Planning and review orchestrators, an autonomous full-driver,
  design specialists (Ecto, LiveView, OTP, Oban, Phoenix, and three Ash agents), reviewers
  (Elixir, testing, security, Iron Laws, requirements), and research and verification agents.
- **48 skills.** Domain and infrastructure knowledge (Ecto, LiveView, Oban, Ash, OTP,
  contexts, security, testing, deploy, and more) that auto-loads by file pattern, plus the
  workflow-command skills.
- **The merged constitution.** `memory/constitution.md` — 9 Articles codifying 53 Iron Laws,
  7 Core Principles, 23 Workflow Laws, the Complexity Router, conditional stack annexes
  (Oban, Oban Pro, Ash, Tidewave), and governance rules. Single-sourced, with four derived
  enforcement copies regenerated on every amendment.
- **23 enforcement hooks.** Dangerous-operation blocking, an Iron-Law verifier, Elixir
  auto-format, freeze gate, deps-audit gate, intent routing, subagent law injection, session
  setup and stack detection, resume and scratchpad checks, and compaction rules — every
  Elixir hook self-gating on `mix.exs` so the spine works in any repository.
- **9 bash scripts** (feature creation, prerequisite checks, plan/tasks setup, agent-context,
  and the git helpers) and **9 templates** (constitution, spec, plan, tasks, checklist, the
  CLAUDE.md and AGENTS.md marker blocks, and the extension and git-config wiring).
- **Project scaffolding.** Plugin manifest and marketplace, MIT license, `NOTICE.md`
  attribution, and lint configuration (markdownlint, yamllint, editorconfig).

### Attribution

- Fuses and adapts `github/spec-kit` (MIT) — the spec-driven flow, command and artifact
  templates, and the `scripts/` automation.
- Fuses and adapts `oliver-kriska/claude-elixir-phoenix` (MIT) — the specialist agents, the
  Elixir/Phoenix domain skills, the enforcement hooks, and the Iron Laws corpus.

[Unreleased]: https://github.com/carlosgr092/claude-speckit-phx-elixir/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/carlosgr092/claude-speckit-phx-elixir/releases/tag/v0.1.0
