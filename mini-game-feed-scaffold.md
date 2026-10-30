# Mini Game Feed Project Scaffold

## Goal
Create the monorepo foundation and the smallest Godot runtime PCK proof of concept required by `features.md`.

## Tasks
- [x] Add npm workspaces, strict TypeScript tooling, lockfile, and repository folders → Verify: `npm install --package-lock-only --ignore-scripts --no-audit --no-fund` resolved the workspace lockfile.
- [x] Add PostgreSQL Compose, schema migrations and deterministic draft fixtures, environment example, and local setup guide → Verify: configuration and SQL match the Phase 1 scope.
- [x] Pin Godot and create persistent-root and test-game PCK source scenes → Verify: scene/project import and export still require Godot 4.5.2, which is unavailable here.
- [ ] Record platform/device PCK test results → Verify: actual Android build loads, unloads, and reloads the PCK; blocked until Godot/device tooling is available.

## Done When
- [x] Phase 1 scaffold is present and documented; Phase 2 remains explicitly gated on a real Android runtime test.
