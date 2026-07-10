# AGENTS.md — Orientation for AI Agents working in `r2-notekeeper`

This file is the entry point for any AI agent (Claude Code, Codex, Cursor, …) operating in this
repository. Read this first, then [`README.md`](README.md), then `RESUME.md` for running state.
Owned and maintained by the `notekeeper` lane (resident writer for this repo).

> **One-paragraph orientation:** `r2-notekeeper` is a **private-notes application on the Reality2
> mesh** — a *downstream* R2 app, **not** a core layer. It runs entirely in the browser: the Reality2
> stack is compiled to WebAssembly (`pkg/`, ~70 KB), so opening the page turns the browser into a node
> in the user's mesh. Notes are end-to-end encrypted; each note operation is a signed R2 event; a
> [relay](https://github.com/reality2-ai/r2-relay) forwards ciphertext between the user's devices but
> cannot read it. There is no account, no server-side storage. It composes `../r2-core` and conforms —
> *as far as it conforms, see §2* — to the canonical specs at `../r2-specifications`.

## 1. Status

**Dormant / no standing work** (per `RESUME.md`, last scoped task complete). Do not start net-new work
here without an explicit directive. One writer per repo — check `RESUME.md` before editing.

**This repo is PUBLIC.** Sample/demo content must stay generic — no real locations, no personal or
place-specific names (see the ROY RULING scrub recorded in `RESUME.md`). `RESUME.md` itself is
intentionally untracked; do not commit it.

## 2. What binds you

- **Authority chain:** `r2-specifications → r2-core → r2-hive / downstream`. This repo is downstream and
  does not redefine the plugin / sentant / ensemble / trust model — it consumes them.
- **It uses a *simplified* slice of R2 transient-networking — R2's goodness tempered to this app's
  context, not the full canon.** R2 is a toolkit applied with judgment; a private-notes app (a handful
  of a user's own devices sharing one trust group, relay-mediated) has simpler sync/topology needs than
  a full peer mesh, so some deviation is **deliberate context-fit, not an unfinished gap.** Therefore:
  - Do **not** treat this repo's TN code as a reference implementation of canon.
  - Do **not** reflexively drive it to full conformance — first understand which pieces it uses and why.
  - For the pieces it *does* use, `../r2-specifications` is the source of truth:
    - device identity & trust-group (TG) identity → `../r2-specifications/specs/r2-core/R2-TRUST.md`
    - discovery → `../r2-specifications/specs/r2-core/R2-BEACON.md`
  - Flag divergences against the specs and judge each as intended context-fit **or** a real gap; don't
    assume either way. When a divergence might be a core/spec issue, escalate (`fleet ask specs …` /
    `fleet ask core …`) rather than forking behaviour locally.

## 3. Where things live

- `index.html` / `notekeeper.html`, `sw.js`, `manifest.json` — the browser app (PWA shell, UI, sync).
- `pkg/` — the Reality2 stack compiled to WebAssembly (loaded by the app).
- `ensemble/` — the Notekeeper R2-DEF score (authored against `R2-DEF §7`).
- `sentant/`, `elixir/`, `config/` — sentant definition and supporting build/config.
- `specs/` — repo-local spec material; canon still lives in `../r2-specifications`.
- `conformance.html` — the published conformance surface (README badge tracks the pass count).

## 4. Working principles (inherited from `r2-specifications/AGENTS.md`)

- **Conjecture-and-refutation** — try to refute every decision; "found nothing against it" is neutral.
- **Occam's razor** — simplest implementation that meets the requirement wins.
- **Disagree with the operator when they are wrong**, politely.
- **Citation discipline** — read/grep/fetch before citing a path or spec section.
- **Cheaper honest move** — downgrade an overclaim rather than overstate.
- **Autonomy stop** — STOP before a hard-to-reverse action and surface it.

The full treatment lives at `../r2-specifications/AGENTS.md` §2.
