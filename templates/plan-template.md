# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/spx:plan` command; its definition describes the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]

**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]

**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]

**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]

**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]

**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]

**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]

**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

[Gates determined based on constitution file]

## Elixir/Phoenix Design
<!-- ELIXIR-PHOENIX START -->

*Fill this ONLY for Elixir/Phoenix projects (mix.exs present) that touch data, web,
jobs, or LiveView — the Elixir-specific counterpart to Technical Context. Delegate the
depth to the specialist agents (see /spx:plan Phase 1). Every point below maps to a
Constitution Principle. Substitute `<app>` with the project's OTP app name.*

- **Ecto / data**: new schemas & fields; migration order (owning column first); indexes; DB
  constraints mirrored by changeset `*_constraint`; preloads required to avoid N+1 (P-IV).
  Delegate to the `ecto-schema-designer` agent.
- **Context boundary**: which context owns this; public API added; confirm zero `Repo.` in
  the web layer — `lib/<app>_web` (single app) or `apps/<app>_web/lib` (umbrella) (P-II).
- **Scope / authorization**: how each resource is scoped to `current_scope`; ownership checks
  before mutation (P-I).
- **LiveView / web**: streams vs assigns for collections; async boundaries; forms/validation.
  Delegate to the `liveview-architect` agent.
- **Jobs**: Oban workers introduced; idempotency & uniqueness strategy (P-V). Delegate to
  the `oban-specialist` agent.
- **Ash** (only if the feature uses Ash): resources/actions/policies. Delegate to the
  `ash-resource-designer` agent.
- **Security surface**: input validation, secrets, authenticated routes (per AGENTS.md).
<!-- ELIXIR-PHOENIX END -->

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/spx:plan command output)
├── research.md          # Phase 0 output (/spx:plan command)
├── data-model.md        # Phase 1 output (/spx:plan command)
├── quickstart.md        # Phase 1 output (/spx:plan command)
├── contracts/           # Phase 1 output (/spx:plan command)
└── tasks.md             # Phase 2 output (/spx:tasks command - NOT created by /spx:plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]

# [REMOVE IF UNUSED] Option 4: Phoenix single app (Elixir, mix.exs at root)
lib/
├── <app>/               # contexts, schemas, business logic (fat context)
│   ├── <context>.ex
│   └── <context>/
└── <app>_web/           # controllers, LiveViews, components (thin web — no Repo.)
    ├── live/
    ├── controllers/
    └── components/

priv/repo/migrations/
test/
├── <app>/               # context tests
└── <app>_web/           # LiveView / controller tests

# [REMOVE IF UNUSED] Option 5: Phoenix umbrella (Elixir, apps/ at root)
apps/
├── <app>/               # domain OTP app
│   ├── lib/<app>/       # contexts, schemas
│   ├── priv/repo/migrations/
│   └── test/
└── <app>_web/           # web OTP app (thin — no Repo.)
    ├── lib/<app>_web/
    └── test/
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
