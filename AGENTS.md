# AGENTS.md — Orientation for AI Agents working in `r2-notekeeper`

This file is the entry point for any AI agent (Claude Code, Codex, Cursor, …) operating in this
repository. Read this first, then [`README.md`](README.md), then `RESUME.md` for running state.

> **One-paragraph orientation:** `r2-notekeeper` is a **private-notes application on the Reality2
> mesh** — a downstream R2 app, not a core layer. It composes `../r2-core` and conforms (as far as it
> conforms — see §2) to the canonical specs at `../r2-specifications`. In the R2 evidence ladder it sits
> between the earliest event-only app and the current full-stack work, and is a candidate payload for
> the transient-networking proof-surface.

## 1. Status

**Dormant / no standing work** (per `RESUME.md`, last scoped task complete). Do not start net-new work
here without an explicit directive. One writer per repo — check `RESUME.md` before editing.

## 2. What binds you

- **Authority chain:** `r2-specifications → r2-core → r2-hive / downstream`. This repo is downstream and
  does not redefine the plugin / sentant / ensemble / trust model — it consumes them.
- **It uses a *simplified* slice of R2 transient-networking — R2's goodness tempered to this app's
  context, not the full canon.** R2 is a toolkit applied with judgment; a private-notes app has
  simpler sync/topology needs than a full peer mesh, so some deviation is deliberate context-fit rather
  than an unfinished gap. Do **not** treat this repo's TN code as a reference implementation of canon,
  and do **not** reflexively drive it to full conformance — first understand which pieces it uses and
  why. For the pieces it *does* use, `../r2-specifications` is the source of truth (e.g. `R2-TRUST`
  device/TG identity, `R2-BEACON` discovery). Flag divergences against the specs and judge each as
  intended context-fit or a real gap; don't assume.

## 3. Working principles (inherited from `r2-specifications/AGENTS.md`)

- **Conjecture-and-refutation** — try to refute every decision; "found nothing against it" is neutral.
- **Occam's razor** — simplest implementation that meets the requirement wins.
- **Disagree with the operator when they are wrong**, politely.
- **Citation discipline** — read/grep/fetch before citing a path or spec section.
- **Cheaper honest move** — downgrade an overclaim rather than overstate.
- **Autonomy stop** — STOP before a hard-to-reverse action and surface it.

The full treatment lives at `../r2-specifications/AGENTS.md` §2.
