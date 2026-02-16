---
project: Generator Network
description: PZ mod linking vanilla generators into fuel-sharing activation clusters with visual coverage highlighting
last_session: 1
continue_with: "Push pending changes, then investigate Issue #4 (MP fuel sync)"

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
- Player feedback on all cluster operations
- Server→client command confirmation

**Tech Stack:** Lua 5.1 (Kahlua2 JVM implementation), Project Zomboid Java API exposed to Lua

## Current Phase

- **Phase 1**: Core functionality (COMPLETE - v0.9.0)
- **Phase 2**: MP compatibility investigation (IN PROGRESS — Issue #4)

## Open Issues

| # | Title | Labels | Priority |
|---|-------|--------|----------|
| 4 | MP fuel sync may not propagate to clients | bug | HIGH |

## Closed Issues

| # | Title | Closed In |
|---|-------|-----------|
| 1 | sandbox-options.txt uses wrong format for Build 42 | e556a29 |
| 2 | activate()/deactivate() methods don't exist on IsoGenerator in B42 | e556a29 |
| 3 | Duplicate mod.info causes potential load issues | e556a29 |
| 5 | Missing common/ folder required for B42 mod detection | 7fc33d2 |
| 6 | mod.info uses pzversion instead of versionMin | 7fc33d2 |
| 7 | Debug sandbox option defaults to true | 7fc33d2 |
| 8 | Command action strings duplicated between client and server | 7fc33d2 |
| 9 | No player feedback after Refuel Cluster | 7fc33d2 |
| 10 | Unconnected generator warning is generic | 7fc33d2 |
| 11 | Coverage highlights clear on any context menu | 7fc33d2 |
| 12 | Server does not send feedback to client | 7fc33d2 |

## Commit History

| Hash | Description | Version |
|------|-------------|---------|
| e7d8efd | Initial upload of mod files | v0.8.8 |
| e556a29 | Fix B42 API compatibility (closes #1, #2, #3) | v0.8.8 |
| 7fc33d2 | Add scaffold, fix issues #5-#12, version bump | v0.9.0 |

**Note:** 7fc33d2 is not yet pushed to origin/main. .gitignore update is uncommitted.

---

## Codebase Stats

| Metric | Value |
|--------|-------|
| Total Lua lines | 469 (shared: 239, client: 165, server: 65) |
| Total commits | 3 (1 unpushed) |
| Open issues | 1 (#4) |
| Closed issues | 11 (#1-#3, #5-#12) |
| Branches | 1 (main) |
| Releases/Tags | 0 |
| Mod version | 0.9.0 |

## Architecture Notes

- **Initialization guard:** `GeneratorNetwork.Initialized` flag prevents double-load
- **Cluster search:** O(n^2) brute-force over (2r+1)^2 tiles — acceptable for r<=50
- **Command constants:** `GN.Commands` table in Shared — single source of truth
- **Coverage highlighting:** Client-only, clears only when opening generator context menus
- **Server feedback:** All cluster operations send `ClusterResult` back to client
- **No rate limiting** on client commands
- **No authorization check** on server (relies on PZ's built-in proximity)

---

## Session Notes

### Session 0 (2026-02-15): Project Scaffolded

**Setup:**
- Full codebase audit (402 lines across 3 Lua files)
- GitHub repo analysis (2 commits, 4 issues, 1 open)
- PZ B42 generator/power API deep dive
- Created Claude Code scaffold structure

**Files created:**
- CLAUDE.md, .claude/context.md, HANDOFF.md
- .claude/rules/ (pz-modding, lua-architecture, development-workflow, thinking-mode)

### Session 1 (2026-02-15): Issues Fixed, v0.9.0

**Changes:**
- Created and fixed GitHub issues #5–#12 (commit 7fc33d2)
- Version bumped from 0.8.8 to 0.9.0
- All three Lua files significantly improved
- .gitignore expanded with comprehensive patterns
- Closed issues #5–#12 on GitHub

**Next:** Push pending changes, investigate Issue #4 (MP fuel sync)
