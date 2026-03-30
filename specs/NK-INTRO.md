# NK-INTRO: Notekeeper — Distributed Notetaking for R2 Trust Groups

| Field      | Value                                                        |
|------------|--------------------------------------------------------------|
| Version    | 0.1 Draft                                                    |
| Date       | 2026-03-31                                                   |
| Status     | Draft                                                        |
| Depends on | R2-SENTANT, R2-WIRE, R2-TRUST, R2-DEF, R2-TRANSPORT         |
| Related    | R2-INTERNET, R2-PROVISION, R2-GQL                            |

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
> "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
> document are to be interpreted as described in RFC 2119.

---

## 1. Introduction

Notekeeper is a distributed notetaking capability for Reality2 (R2). It is a
swarm (R2-DEF) of sentants that enables notes to be created, edited, tagged,
linked, and synced across all devices in a trust group -- without a central
server, without Tailscale, and without any third-party accounts.

Notekeeper exists to validate the R2 distributed stack before building more
complex capabilities like Anthill. It exercises: R2-TRUST (device provisioning,
trust groups), R2-WIRE (event protocol), R2-TRANSPORT (WebSocket binding), and
the cloud relay concept that replaces Tailscale for NAT traversal.

### 1.1 Purpose

Notekeeper serves three purposes:

1. **A useful tool.** Distributed notes across your devices, private by
   default. No cloud database, no accounts, no subscriptions.

2. **An R2 validation vehicle.** Proves that trust groups, event sync, and
   relay work in practice. Every R2 capability exercised here is one that
   Anthill will depend on -- Notekeeper validates them first at lower
   complexity.

3. **A foundation.** The patterns validated here -- temporal event stores,
   relay-based NAT traversal, offline-first sync -- feed directly into
   Anthill federation and R2-INTERNET.

### 1.2 Design Principles

1. **No central server.** Notes live on your devices, not in a cloud database.
   The relay routes encrypted frames but stores nothing permanently.

2. **No third-party dependencies.** No Tailscale, no Google, no accounts.
   R2-TRUST IS the identity layer. A device is trusted because you
   provisioned it, not because a third party vouches for it.

3. **Swarm, not application.** Notekeeper is a YAML definition (R2-DEF) that
   loads sentants and binds plugins. There is no monolithic binary -- the
   capability emerges from the swarm.

4. **Events carry decisions.** Note operations are R2 events (<=256 bytes on
   the wire). Content travels via the plugin data plane; events coordinate
   state transitions.

5. **Relay is untrusted.** End-to-end encryption via R2-TRUST ensures the
   relay cannot read note content. The relay is a dumb pipe that routes
   frames by trust group.

6. **Works offline.** Events are queued locally when the device is
   disconnected. On reconnect, the sync-agent performs catchup to reconcile
   state.

7. **Human-readable storage.** Notes are persisted as a JSONL event log --
   the same temporal pattern used by Anthill knowledge stores. Any text
   editor can inspect the log.

### 1.3 Terminology

| Term              | Definition                                                                                          |
|-------------------|-----------------------------------------------------------------------------------------------------|
| Notekeeper        | A distributed notetaking capability implemented as an R2 swarm.                                     |
| Swarm             | A coordinated group of sentants loaded from a single R2-DEF YAML definition.                        |
| Note              | A unit of content: title, body (Markdown), tags, and links to other notes.                          |
| Event Log         | A JSONL file recording every note operation as a temporal event. Append-only, human-readable.        |
| Relay             | A cloud-hosted sentant that routes encrypted R2-WIRE frames between devices behind NAT.             |
| Catchup           | The process by which a reconnecting device receives missed events from peers or the relay buffer.    |
| Trust Group       | An R2-TRUST boundary defining which devices may sync notes with each other.                         |
| Device Credential | A cryptographic identity issued to a device when it joins a trust group (R2-TRUST, R2-PROVISION).   |
| Colony Key        | The shared symmetric key for a trust group, used for end-to-end encryption of note content.         |
| Hive              | The runtime host for one or more swarms. Each device runs one hive.                                 |

---

## 2. Architecture

The Notekeeper capability consists of a local swarm running on each device and
an optional cloud relay swarm for NAT traversal.

### 2.1 Sentants

A conforming Notekeeper hive MUST instantiate the following sentants:

- **note-store** (class: `r2.capability.notekeeper`) -- Manages the note
  collection. Receives `note.create`, `note.edit`, `note.delete`, `note.tag`,
  and `note.link` events. Maintains current state in memory, backed by a
  temporal event log on disk. There MUST be exactly one note-store per hive.

- **sync-agent** (class: `r2.capability.sync`) -- Handles event propagation
  between devices in the trust group. Manages catchup for reconnecting
  devices. Applies vector-clock ordering to resolve concurrent edits. There
  MUST be exactly one sync-agent per hive.

### 2.2 Plugins (Existing R2 Infrastructure)

Notekeeper uses existing R2 plugins. No custom plugins are required:

- **r2-transport** -- WebSocket binding for relay and direct connections.
- **r2-trust** -- Device authentication, trust group management, end-to-end
  encryption.

### 2.3 Relay (Separate Swarm, Runs on Cloud Hive)

- **relay** (class: `r2.capability.relay`) -- Routes R2-WIRE frames between
  devices. The relay is stateless and untrusted. It authenticates connections
  via R2-TRUST device credentials and MUST NOT persist note content. The relay
  SHOULD buffer recent events (bounded by time and count) to support catchup
  for devices that reconnect within the buffer window.

### 2.4 UX

- **Phoenix PWA** -- A responsive web interface for creating, editing, and
  browsing notes. Works on phone, tablet, and desktop. Installable as a home
  screen progressive web application.
- The UX communicates with local sentants via Phoenix channels and R2-GQL.
- The UX MUST NOT communicate directly with the relay or with remote devices.
  All sync is handled by the sync-agent.

---

## 3. R2 Stack Usage

The following table maps each R2 specification to its role in Notekeeper:

| R2 Spec        | Notekeeper Usage                                                          |
|----------------|---------------------------------------------------------------------------|
| R2-SENTANT     | note-store and sync-agent are IPUCO+D sentants                            |
| R2-WIRE        | Note events encoded as R2 wire frames (<=256 bytes)                       |
| R2-TRUST       | Trust group identity, device provisioning, end-to-end encryption          |
| R2-DEF         | Swarm YAML definition for the notekeeper capability                       |
| R2-TRANSPORT   | WebSocket binding for relay and direct connections                        |
| R2-CBOR        | Event encoding on the wire                                                |
| R2-FNV         | Event name hashing for wire-level dispatch                                |
| R2-GQL         | GraphQL API for the web UX                                                |
| R2-PROVISION   | Device join flow (QR code, join code)                                     |
| R2-INTERNET    | Cloud relay for NAT traversal -- the key validation target                |
| R2-BEACON      | mDNS local discovery for same-LAN direct connections                      |

---

## 4. What This Validates

Notekeeper is explicitly designed to validate R2 distributed capabilities
before they are needed by Anthill. The following table defines what is
validated and the success criteria:

| R2 Capability             | What Is Validated                                              | Success Criteria                                                                 |
|---------------------------|----------------------------------------------------------------|----------------------------------------------------------------------------------|
| R2-TRUST trust groups     | Device provisioning, join flow, credential issuance            | A new device joins a trust group via QR code and syncs notes within 30 seconds   |
| R2-TRUST encryption       | End-to-end encryption via colony key                           | Relay operator cannot read note content; verified by inspection of relay logs     |
| R2-WIRE event protocol    | Event dispatch, ordering, delivery                             | Events arrive in causal order on all devices in the trust group                  |
| R2-TRANSPORT WebSocket    | Persistent connections, reconnection, heartbeat                | Connection survives network interruption; catchup completes on reconnect         |
| R2-INTERNET relay         | NAT traversal without Tailscale                                | Two devices on different NATs sync notes via relay without manual configuration  |
| R2-BEACON local discovery | Same-LAN direct connection                                     | Two devices on the same LAN discover each other and sync without relay           |
| R2-DEF swarm loading      | YAML definition loads sentants and binds plugins               | Swarm starts from YAML with no manual sentant creation                           |
| Temporal event store      | Append-only JSONL log, replay, compaction                      | Event log replays to identical state; compaction reduces log size without loss    |
| Offline operation         | Local event queue, reconnect, catchup                          | Notes created offline appear on all devices after reconnection                   |

---

## 5. Relationship to Anthill

Every pattern validated by Notekeeper feeds directly into Anthill:

| Notekeeper Pattern           | Anthill Equivalent                                                          |
|------------------------------|-----------------------------------------------------------------------------|
| Relay-based NAT traversal    | ANTHILL-FEDERATION -- removes Tailscale dependency from Anthill             |
| Event sync across devices    | Knowledge graph sync across Anthill nodes                                   |
| Temporal event store (JSONL) | ANTHILL-KNOWLEDGE v0.2 -- temporal knowledge persistence                    |
| Trust group provisioning     | ANTHILL-TRUST / ANTHILL-ONBOARDING -- device and user identity              |
| Offline queue and catchup    | ANT resilience -- agents continue reasoning during network partitions       |
| No-Tailscale connectivity    | Removes the last external dependency from the Anthill distributed stack     |

Notekeeper is intentionally simpler than Anthill. Notes are flat documents
with tags and links; knowledge graphs are directed graphs with Bayesian
confidence. By validating the distributed infrastructure on a simpler data
model first, Notekeeper de-risks the Anthill federation work.

---

## 6. Specification Suite

The Notekeeper specification suite consists of the following documents:

| Spec ID   | Title                              | Scope                                                         |
|-----------|------------------------------------|---------------------------------------------------------------|
| NK-INTRO  | Introduction and Architecture      | This document. Overview, architecture, design principles.     |
| NK-DATA   | Data Model and Event Log           | Note structure, event types, JSONL format, sync semantics.    |
| NK-RELAY  | Relay and Sync Protocol            | Relay behaviour, catchup protocol, encryption, NAT traversal. |
| NK-UX     | User Experience                    | Phoenix PWA interface, GraphQL API, offline UX behaviour.     |

---

## 7. Conformance

A conforming Notekeeper implementation:

1. MUST instantiate a note-store and sync-agent sentant as defined in
   Section 2.1.

2. MUST persist all note operations as a temporal event log in JSONL format
   as defined in NK-DATA.

3. MUST use R2-TRUST for device identity and end-to-end encryption. Note
   content MUST NOT be readable by the relay or any entity outside the trust
   group.

4. MUST support offline operation. Events created while disconnected MUST be
   queued locally and synced on reconnect.

5. MUST support catchup: a device that reconnects after a period of
   disconnection MUST receive all missed events and converge to the same
   state as other devices in the trust group.

6. MUST load the swarm from a YAML definition conforming to R2-DEF.

7. SHOULD support same-LAN direct connections via R2-BEACON when devices
   are on the same network.

8. SHOULD support relay-based NAT traversal via R2-INTERNET when devices
   are on different networks.

9. MAY implement additional note features (attachments, rich formatting)
   provided they conform to the event model defined in NK-DATA.
