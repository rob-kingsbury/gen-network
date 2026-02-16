---
project: Generator Network
description: PZ mod linking vanilla generators into fuel-sharing activation clusters with visual coverage highlighting
last_session: 0
continue_with: "Address Issue #4 (MP fuel sync) and general improvements"

tech:
  stack: pz-lua-mod
  tools: [Lua 5.1 (Kahlua2), Project Zomboid B42.12+, Git, GitHub]

paths:
  src: GeneratorNetwork_42/42/media/lua/
  mod_root: GeneratorNetwork_42/
  rules: .claude/rules/
  shared: GeneratorNetwork_42/42/media/lua/shared/
  client: GeneratorNetwork_42/42/media/lua/client/
  server: GeneratorNetwork_42/42/media/lua/server/

commands:
  issues: gh issue list --state open
  log: git log --oneline
---

# Generator Network Context

## Project Overview

A Project Zomboid mod (Build 42.12+) that replaces the vanilla per-generator power radius with a networked cluster system. Players can link nearby generators into clusters that share fuel, activate/deactivate together, and display visual coverage.

**Core Features:**
- Cluster discovery via radius-based spatial search
- Fuel pooling and equal distribution across cluster
- Batch activate/deactivate with connection and fuel validation
- Client-side visual coverage highlighting on floor tiles
- Configurable cluster radius and debug logging via sandbox options

**Tech Stack:** Lua 5.1 (Kahlua2 JVM implementation), Project Zomboid Java API exposed to Lua

## Current Phase

- **Phase 1**: Core functionality (COMPLETE - v0.8.8)
- **Phase 2**: Bug fixes and MP compatibility (IN PROGRESS)

## Open Issues

| # | Title | Labels | Priority |
|---|-------|--------|----------|
| 4 | MP fuel sync may not propagate to clients | bug | HIGH |

## Recent Changes

### Commit e556a29 (2026-01-24)
- Fixed sandbox-options.txt to B42 FORMAT (VERSION = 1, dotted names)
- Changed SandboxVars access from flat to nested
- Replaced nonexistent activate()/deactivate() with setActivated() + setSurroundingElectricity()
- Removed duplicate 42/mod.info
- Closes #1, #2, #3

### Commit e7d8efd (2026-01-24)
- Initial upload of mod files v0.8.8

---

## Codebase Stats

| Metric | Value |
|--------|-------|
| Total Lua lines | 402 (shared: 219, client: 142, server: 41) |
| Total commits | 2 |
| Open issues | 1 (#4) |
| Closed issues | 3 (#1, #2, #3) |
| Branches | 1 (main) |
| Releases/Tags | 0 |

## Architecture Notes

- **Initialization guard:** `GeneratorNetwork.Initialized` flag prevents double-load
- **Cluster search:** O(n^2) brute-force over (2r+1)^2 tiles — acceptable for r<=50
- **Command strings:** "RefuelCluster", "ClusterOn", "ClusterOff" duplicated between client/server (no constants)
- **Coverage highlighting:** Client-only, clears on any context menu open
- **No rate limiting** on client commands
- **No authorization check** on server (relies on PZ's built-in proximity)

## Audit Findings

### Strengths
- Robust triple-validation of generators (instanceof, square, objectIndex)
- Proper client/server/shared separation
- MP-safe fuel sync with sendObjectChange()
- Defensive programming (graceful skip of invalid generators)
- Comprehensive debug logging

### Areas for Improvement
1. **Issue #4:** sendObjectChange("fuel") may not propagate — investigate gen:sync()
2. **Missing `common/` folder:** B42 requires this for mod detection (can be empty)
3. **Translation file missing wrapper:** Sandbox_EN.txt needs `Sandbox_EN = { }` table wrapper and page name entry
4. **mod.info `pzversion` field:** Should be `versionMin=42.12.0` (documented B42 field)
5. **Debug default is `true`:** Should be `false` for release builds
6. **No command constants:** Action strings duplicated across files
7. **No player feedback on refuel:** Silent success
8. **Coverage highlights fragile:** Cleared on ANY context menu, not just generator menus
9. **Generic unconnected warning:** Doesn't specify which generators failed
10. **No sendServerCommand feedback:** Server doesn't confirm actions back to client

---

## Session Notes

### Session 0 (2026-02-15): Project Scaffolded

**Setup:**
- Full codebase audit (402 lines across 3 Lua files)
- GitHub repo analysis (2 commits, 4 issues, 1 open)
- PZ B42 generator/power API research
- Created Claude Code scaffold structure

**Files created:**
- CLAUDE.md - Project governance
- .claude/context.md - This file
- .claude/rules/lua-architecture.md - Lua coding standards
- .claude/rules/pz-modding.md - PZ B42 API reference and conventions
- .claude/rules/development-workflow.md - Working patterns
- .claude/rules/thinking-mode.md - Deep analysis triggers
- HANDOFF.md - Session continuity

**Next:** Address Issue #4 (MP fuel sync), add command constants, improve player feedback
