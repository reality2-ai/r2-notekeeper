# Notekeeper ensemble

This directory holds the R2-ENSEMBLE score for Notekeeper, the first
production ensemble authored against R2-DEF §7 "Ensemble Definition
Schema".

## Files

- `ensemble.yaml` — the normative ensemble score (R2-DEF §7.9 example made real)
- `web/` — (future) the static bundle, GraphQL schema, and resolver module
  registered with the hive's R2-WEB singleton at `/notekeeper/*`

## Relationship to the current Notekeeper

The existing browser-WASM Notekeeper at the repo root (`index.html`,
`pkg/r2_wasm*`) is the current shipping implementation. It talks
directly to the relay over WebSocket and holds all state in
`localStorage`. This is a working app that does not yet use the
ensemble runtime framework.

The ensemble score in this directory is the **target** form of
Notekeeper once the framework (B-phases in
`docs/planning/cheerful-discovering-neumann.md`) lands. The migration
path from the current app to the ensemble form is:

1. B0 (this spec) — ensemble score schema defined, Notekeeper score
   drafted (complete 2026-04-14).
2. B1 — `r2-dispatch` crate + router seam in r2-hive.
3. B2 — BEAM ensemble loader accepts this file and instantiates the
   Note sentant + notekeeper.sync plugin.
4. B3 — R2-WEB singleton accepts the registration and serves the
   Notekeeper UI at `/notekeeper/*` with stitched GraphQL.
5. Notekeeper browser UI rewrites: GraphQL client instead of direct
   R2-WIRE over WebSocket. The UI becomes portable across any
   conformant R2 hive.

## Validation

Until `r2-ensemble` (loader crate) lands, validation is manual:
read R2-DEF §7 and verify field presence.
