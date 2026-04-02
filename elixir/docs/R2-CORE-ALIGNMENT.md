# R2 Core Alignment for Notekeeper

## Purpose

`r2-notekeeper` is not the end goal. It is the first vertical slice used to
force reusable implementation out of `r2-specifications` into `r2-core`, the
server-hosted `r2-web` plugin surface, and the browser-hosted `r2-wasm`
runtime.

The test for any work here is:

1. Does it validate a spec requirement?
2. Does it belong in a reusable R2 layer?
3. Is the capability-specific code thin enough that another swarm could reuse
   the same mechanism?

If the answer to `2` is "yes", it should not stay bespoke inside the
Notekeeper web extension.

## Current State

### What already exists in `r2-core`

The current Elixir runtime in `r2-core` already provides the start of a
spec-aligned local sentant engine:

- `R2.Hive`
  Loads definitions, supervises sentants, tracks public metadata.
- `R2.Sentant.Definition`
  Parses `R2-DEF`-style sentant and swarm documents.
- `R2.Sentant.Supervisor`, `Automation`, `Comms`, `Actions`
  Provide a local FSM runtime with action pipelines.
- `R2.Plugin.Manager`
  Provides a hive-local plugin invocation path and a standard plugin result
  envelope.

This is enough to run local sentants and exercise `R2-DEF`, `R2-SENTANT`, and
part of `R2-PLUGIN`.

### What `r2-notekeeper` currently adds

- A local event-sourced note store with JSONL persistence.
- A Notekeeper web extension serving a local browser UI.
- A temporary REST API for browser-driven CRUD.

The note store is useful capability logic. The REST layer is currently only
development scaffolding.

## Spec Boundary

### What belongs in `r2-core`

These are reusable runtime concerns, not Notekeeper concerns:

- Sentant lifecycle and supervision.
- Swarm loading from `R2-DEF`.
- Hive-local event bus abstraction.
- Plugin registration, invocation, and result routing.
- Public sentant metadata for management/query projection.
- Capability aggregation for `R2-CAP`.
- Trust and credential interfaces for `R2-TRUST`.
- Runtime event injection from external surfaces such as web, BLE, relay, or
  CLI.

### What belongs in `r2-web`

Per `R2-WEB`, `r2-web` is the server-hosted web plugin binding for a hive, not
an app-local controller tier. Reusable `r2-web` concerns are:

- Static bundle serving for a swarm UX.
- WebSocket endpoint and browser session lifecycle.
- Browser-as-device authentication and message signing.
- GraphQL endpoint exposing `R2-GQL` base schema plus swarm extensions.
- Event forwarding from local hive to browser clients.
- Command/query injection from browser to hive runtime.
- Subscription plumbing between WebSocket clients and hive events.

### What belongs in `r2-wasm`

Per the newer browser-hive direction in `R2-INTERNET` and `R2-WEB`, `r2-wasm`
is the browser-resident hive host. Reusable `r2-wasm` concerns are:

- Running the R2 runtime inside a browser as a real hive.
- Trust-group provisioning, persistence, and restore in browser storage.
- Browser-native transport adapters such as WebSocket, WebBluetooth, and
  WebUSB.
- Exposing a local runtime surface to the page without requiring a
  server-hosted hive.
- Supporting the same swarm UX against local browser-hosted state and events.

### What belongs in `r2-notekeeper`

These should remain capability-specific:

- Note domain model.
- Note event log and snapshots.
- Note-specific queries and mutations.
- Note-specific UI screens and interaction design.
- Sync-agent behaviour specific to note reconciliation and catchup.

## Gap Analysis

### `r2-core` gaps exposed by Notekeeper

Notekeeper is currently forced to bypass or invent several layers that should
exist centrally:

1. There is no explicit hive event bus abstraction for external adapters.
   `R2.Hive.send_event/2` targets a sentant directly, but `R2-WEB` and future
   adapters need a stable way to inject commands and observe public events.

2. There is no management/query projection yet.
   `R2-GQL` expects a typed view of sentants, swarms, devices, trust groups,
   and events. `R2.Hive` exposes enough metadata to start this but no schema or
   boundary exists.

3. Plugin management is too narrow.
   `R2.Plugin.Manager` can invoke handlers, but there is no formal plugin
   behaviour or lifecycle contract for a long-running plugin such as `r2-web`.

4. Trust is not integrated.
   There is no credential model, browser device identity, or signed external
   message path yet.

5. Capability advertisement is not wired.
   `R2-CAP` needs aggregated public event hashes from the loaded sentants, but
   the runtime does not yet publish that as a first-class function.

### `r2-web` gaps exposed by Notekeeper

The current server-hosted Notekeeper web path is useful for prototyping, but
it is not yet a reusable R2 web plugin because it lacks:

- signed browser-device authentication
- WebSocket command/event transport
- `R2-GQL` schema
- shared plugin boundary with `r2-core`
- browser provisioning and trust-group flows

### `r2-wasm` gaps exposed by Notekeeper

The new browser-hive path is now the larger missing piece. Notekeeper does not
yet have:

- a browser-hosted hive bootstrap path
- note UX running against a local WASM-hosted runtime
- local browser persistence wired to trust and sentant state
- browser-native mesh transport hooks

### `r2-notekeeper` gaps exposed by the specs

Against `NK-INTRO`, `NK-RELAY`, and `NK-UX`, Notekeeper still lacks:

- sync-agent sentant
- relay integration
- trust-group identity and encryption
- catchup and offline sync
- `R2-GQL` UX integration
- real-time browser subscriptions

## Assessment of Recent Work

### Keep

These changes are still useful:

- `Notekeeper.NoteStore` as capability-domain logic.
- JSONL persistence and note tests.
- Static UI shell as temporary UX exploration.

### Treat as temporary scaffolding

These should not harden into the final architecture:

- REST controllers as the primary interface.
- Phoenix controller-driven app logic inside the Notekeeper web extension.
- direct app-specific wiring where a reusable `r2-web` plugin contract should
  exist.

The REST layer is acceptable as a developer bootstrap, but not as the final
shape of `R2-WEB`.

## Recommended Refactor Order

### Phase 1: strengthen `r2-core`

1. Add a first-class hive runtime facade for:
   - listing sentants and swarms
   - injecting public commands
   - subscribing to hive events
   - exposing plugin and capability metadata
2. Introduce a small plugin behaviour for long-running hive plugins.
3. Add capability aggregation from sentant public events.

### Phase 2: build `r2-web` as a reusable plugin

1. Create a reusable `r2-web` app or plugin package outside Notekeeper.
2. Implement:
   - static bundle serving
   - WebSocket endpoint
   - browser session/auth hooks
   - GraphQL endpoint
   - event subscription bridge to the hive runtime
3. Keep the plugin generic. It should know about hives and swarms, not notes.

### Phase 3: build `r2-wasm` as a browser hive

1. Create the browser bootstrap path for a local WASM-hosted hive.
2. Reuse `r2-core` contracts for trust, transport, and runtime state.
3. Make the same swarm UX viable against either `r2-web` or `r2-wasm`.

### Phase 4: thin `r2-notekeeper` back down

1. Move browser transport concerns out of the Notekeeper web extension.
2. Keep only:
   - Notekeeper GraphQL schema extensions
   - note-specific event handlers
   - note-specific static bundle
3. Replace REST-first UI paths with GraphQL + subscriptions.

## Immediate Next Step

The highest-value next move is not another Notekeeper feature. It is to define
the minimal reusable boundary between `r2-core`, `r2-web`, and `r2-wasm`.

Concretely:

1. define the shared runtime API that `r2-web` and `r2-wasm` will call
2. implement a small `R2.GQL` base schema in `r2-core`
3. convert the Notekeeper web extension from REST-first to GraphQL plus event
   streaming

That sequence keeps Notekeeper as the proving ground while ensuring the real
investment lands in reusable R2 infrastructure.
