# Notekeeper Evolution — From Notes to Distributed Content Store

**Version:** 0.1
**Date:** 2026-03-31
**Status:** Design direction (informative)

---

## 1. Purpose

This document describes the planned evolution of the notekeeper capability
from simple note sync to a general distributed content store for R2 trust
groups. The notekeeper specs (NK-*) describe Phase 1. This document
outlines Phases 2 and 3 so that architectural decisions made now do not
preclude future evolution.

---

## 2. Evolution Phases

### Phase 1: Notes (current)

Markdown notes synced across all devices in a trust group. Every device
stores every note. Simple, useful, validates the R2 stack.

- Content type: text/markdown only
- Storage: all devices store everything (no negotiation)
- Metadata: title, tags, links, timestamps
- Sync: full replication via R2 events

### Phase 2: Media and Negotiated Storage

Extend to photos, voice memos, documents, and video clips. Introduce
negotiated storage placement — not every device stores everything.

- Content types: any MIME type
- Storage: request-to-store protocol (§3)
- Metadata: content-specific fields (dimensions, duration, location)
- Sync: events replicated to all; content placed on capable devices

### Phase 3: Epistemic Content (Anthill Integration)

Content carries epistemic metadata — confidence, evidence chains,
citations, decay categories. The content store becomes the persistence
layer for Anthill's knowledge graphs. Notes become conjectures.

- Metadata: confidence, evidence_types, citations, source_id,
  beneficial_impact, decay_category, epistemic_chain
- Storage: same negotiated placement, but with epistemic awareness
  (high-confidence content gets higher redundancy?)
- Sync: epistemic events (same as ANTHILL-KNOWLEDGE v0.2)

---

## 3. Request-to-Store Protocol

### 3.1 Motivation

A watch cannot store 10GB of photos. A phone on mobile data should not
download a video it didn't request. Storage must be negotiated, not
assumed.

### 3.2 Protocol

**Store request** (broadcast to trust group):
```json
{
  "type": "store_request",
  "id": "obj-<8hex>",
  "content_type": "image/jpeg",
  "size": 2457600,
  "hash": "sha256:<hex>",
  "redundancy": 2,
  "retention_days": 90,
  "priority": "normal"
}
```

**Store accept** (from capable devices):
```json
{
  "type": "store_accept",
  "id": "obj-<8hex>",
  "device": "<device-id>",
  "capacity": "full"
}
```

Capacity values:
- `full` — will store the complete content
- `thumbnail` — will store a reduced version (images/video)
- `metadata` — will store only the metadata (event record)

**Store transfer** (content delivery):
Once sufficient accepts are received (>= requested redundancy), the
originating device transfers content to accepting devices via the data
plane. Transfer is direct (LAN) or via relay, encrypted with trust
group DEK.

**Store transfer request** (rebalancing):
```json
{
  "type": "store_transfer_request",
  "id": "obj-<8hex>",
  "from": "<device-id>",
  "reason": "low_space"
}
```

A device running low on space can request that another device take over
storage. Other devices respond with `store_accept`. After transfer
completes, the originating device releases its copy.

### 3.3 Metadata Update

After each placement change, the metadata is updated:
```json
{
  "type": "store_placed",
  "id": "obj-<8hex>",
  "stored_on": ["device-A", "device-B", "device-C"],
  "redundancy": 3,
  "requested_redundancy": 2
}
```

All devices in the trust group maintain this metadata (it's tiny —
just the placement map). The content itself lives only on accepting
devices.

### 3.4 Retrieval

Any device can request content from any device that stores it:
```json
{
  "type": "retrieve_request",
  "id": "obj-<8hex>"
}
```

The nearest/fastest storing device responds with the content. If
multiple devices store the content, the requesting device SHOULD prefer
direct LAN connections over relay.

### 3.5 Redundancy Monitoring

A background process monitors redundancy levels:
- If a device goes offline for >N days and content drops below
  requested redundancy: emit `store_request` to find new storage.
- If a device is permanently removed (revoked): redistribute its
  content automatically.

---

## 4. Metadata

### 4.1 Core Metadata (all content, all phases)

Every stored object carries core metadata that is replicated to ALL
devices in the trust group — regardless of whether the device stores the
actual content. This enables every device to search, browse, and filter
the full catalogue.

```json
{
  "id": "obj-a1b2c3d4",
  "content_type": "image/jpeg",
  "hash": "sha256:...",
  "size": 2457600,
  "created_at": "2026-03-31T14:23:00Z",
  "created_by": "device-id",
  "modified_at": "2026-03-31T15:30:00Z",
  "modified_by": "device-id",

  "who": "Roy Davies",
  "what": "Photo of Wairoa River at flood stage",
  "where": {
    "name": "Wairoa River, Hawke's Bay",
    "lat": -39.0567,
    "lon": 177.0542
  },
  "when": "2026-03-31T14:23:00Z",
  "tags": ["wairoa", "flood", "monitoring"],

  "stored_on": ["device-A", "device-B"],
  "redundancy": 2,
  "requested_redundancy": 2,
  "retention_days": 90
}
```

The core fields — **who, what, where, when** — are human-facing context
that makes content discoverable across all devices. A watch shows "Roy's
photo of Wairoa River flood, 2:23pm" without needing the actual image.
A phone shows a thumbnail. The home server has the full resolution file.

Core metadata is small (~500 bytes per object). A collection of 10,000
objects produces ~5MB of metadata — trivially fits on any device,
including a watch.

### 4.2 Content-Type-Specific Metadata

Additional metadata fields depend on the content type. These extend the
core metadata — they do not replace it.

#### Notes (Phase 1)

```json
{
  "content_type": "text/markdown",
  "title": "River monitoring setup notes",
  "word_count": 342,
  "links": [{ "target": "obj-b2c3d4e5", "relation": "references" }],
  "headings": ["Equipment", "Installation", "Calibration"]
}
```

#### Images (Phase 2)

```json
{
  "content_type": "image/jpeg",
  "dimensions": { "width": 4032, "height": 3024 },
  "device_context": "rear_camera",
  "orientation": 1,
  "thumbnail": "<base64 of 200px thumbnail>"
}
```

Note: `thumbnail` is included in the metadata so devices that don't
store the full image can still display a preview. Thumbnails are
typically 5-15KB — still small enough to replicate everywhere.

#### Voice Memos (Phase 2)

```json
{
  "content_type": "audio/opus",
  "duration_secs": 45,
  "sample_rate": 48000,
  "transcript": "Checked sensor three at the bridge. Water level is..."
}
```

Transcripts enable text search across voice memos from any device.

#### Documents (Phase 2)

```json
{
  "content_type": "application/pdf",
  "title": "Wairoa Flood Risk Assessment 2026",
  "author": "Hawke's Bay Regional Council",
  "pages": 42,
  "summary": "Assessment of flood risk for the Wairoa River catchment..."
}
```

#### Epistemic Content (Phase 3 — Anthill)

```json
{
  "confidence": 0.85,
  "log_odds": 1.763,
  "evidence_types_seen": ["corroboration", "refutation_survived"],
  "citations": ["cite-a1b2c3d4"],
  "source_id": "ant:Alfred",
  "beneficial_impact": 0.6,
  "decay_category": "fact",
  "half_life_days": 30,
  "last_evidence_at": "2026-03-28T15:00:00Z"
}
```

### 4.3 Metadata as Knowledge Graph

The metadata catalogue is itself a lightweight knowledge graph:

- **Nodes** are content objects (notes, photos, documents).
- **Edges** are links between them (note references photo, document
  cites another document, voice memo describes a location).
- **Tags** provide a flat taxonomy.
- **Who/what/where/when** provide faceted search dimensions.

This graph is small enough to replicate to every device and query
locally. As the notekeeper evolves toward Anthill integration (Phase 3),
the metadata graph becomes a proper epistemic graph with confidence,
evidence, and citations — the same structure as ANTHILL-KNOWLEDGE.

### 4.4 Metadata Replication

All metadata MUST be replicated to all devices in the trust group:

- Metadata events use the same sync protocol as content events.
- Metadata is included in the JSONL event log.
- Content placement (`stored_on`) is metadata — all devices know where
  everything is, even if they don't have it locally.
- Unknown metadata fields MUST be preserved during sync — a Phase 1
  device syncing with a Phase 2 device MUST NOT drop fields it doesn't
  understand.

### 4.5 Epistemic Content (Phase 3)

```json
{
  "confidence": 0.85,
  "log_odds": 1.763,
  "evidence_types_seen": ["corroboration", "refutation_survived"],
  "citations": ["cite-a1b2c3d4"],
  "source_id": "ant:Alfred",
  "beneficial_impact": 0.6,
  "decay_category": "fact",
  "half_life_days": 30,
  "last_evidence_at": "2026-03-28T15:00:00Z"
}
```

---

## 5. Architectural Constraints for Phase 1

The notekeeper specs (NK-*) describe Phase 1 only. However, the
following architectural decisions are made now to avoid blocking
future phases:

1. **Content is identified by hash.** Even for notes, content is
   addressed by SHA-256 hash. This enables deduplication and integrity
   verification in later phases.

2. **Events and content are separated.** Events (<256 bytes) carry
   metadata; the data plane carries content. This separation already
   supports large media in Phase 2.

3. **Metadata is extensible.** The note model uses a flat JSON structure
   that can be extended with new fields without breaking existing
   devices. Unknown fields MUST be preserved on sync.

4. **Device capabilities are discoverable.** Each device should
   advertise its storage capacity and connectivity so the
   request-to-store protocol can make informed decisions in Phase 2.

5. **The relay is content-agnostic.** R2-TRANSPORT-RELAY routes frames
   without parsing. Adding new content types requires no relay changes.

---

## 6. Relationship to R2

The request-to-store protocol (§3) is general R2 infrastructure. It
could become a new R2 spec (**R2-STORE**) if other capabilities need it:

- Mariko: store sensor data across a mesh of gateway devices
- Anthill: distribute knowledge graph storage across reasoning nodes
- Notekeeper: distribute media across personal devices

The evolution follows the same Popperian approach as ANTHILL-KNOWLEDGE:
start specific (notekeeper), generalise when validated (R2-STORE).
