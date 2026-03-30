# NK-DATA: Note Data Model, Events, and Temporal Storage

| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Version     | 0.1 Draft                                                    |
| Date        | 2026-03-31                                                   |
| Status      | Draft                                                        |
| Depends on  | NK-INTRO, R2-WIRE, R2-CBOR                                  |
| Related     | NK-RELAY, R2-KNOWLEDGE                                       |

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in [RFC 2119][rfc2119].

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt

---

## 1. Introduction

Notes are stored as a temporal event log. Each operation -- create,
edit, delete, tag, link -- is an event with a timestamp. Current state
is materialised from the event stream. This is the same pattern used
by R2-KNOWLEDGE for epistemic graphs, applied to a simpler domain.

Where R2-KNOWLEDGE tracks Bayesian confidence, evidence chains, and
epistemic decay, NoteKeeper tracks plain-text notes with tags and
links. The storage architecture is identical: append-only event log,
day-partitioned JSONL files, materialised snapshots, and rebuildable
indexes. The complexity budget is deliberately lower.


### 1.1 Design Principles

1. **Events are the source of truth** -- current note state is derived.
   The event log is append-only. The current set of notes is a
   materialised view that can be rebuilt from scratch by replaying all
   events. If the snapshot is lost or corrupted, the event log alone
   is sufficient to reconstruct the complete current state.

2. **JSONL event log** -- human-readable, append-only, day-partitioned.
   Storage uses JSON and JSONL exclusively. CBOR is used only on the
   R2 wire (see Section 8). Debuggability and auditability are more
   important than on-disk compactness for a personal note store.

3. **Works offline** -- events are queued locally and replayed on
   sync. A device that has been offline for days, weeks, or months
   simply appends its local events and replays incoming events from
   peers. No central server is required.

4. **Conflict resolution: last-write-wins by timestamp** -- simple
   and sufficient for personal notes. When two devices edit the same
   note concurrently, the event with the later timestamp wins. More
   sophisticated merge strategies (CRDTs, OT) are out of scope for
   this version.


### 1.2 Terminology

| Term               | Definition                                                                  |
|--------------------|-----------------------------------------------------------------------------|
| Note Event         | An immutable record of something that happened to a note. The atomic unit of the event store. |
| Event Log          | An append-only, day-partitioned JSONL file containing note events. The source of truth. |
| Materialised State | The current state of all notes, derived from the event log. A JSON snapshot used for fast startup. Disposable and rebuildable. |
| Snapshot           | Synonym for materialised state. A point-in-time capture of all notes. |
| Device ID          | An opaque string identifying the device that originated an event. Format is implementation-defined. |

---

## 2. Note Model


### 2.1 Note Structure (Materialised State)

The materialised state of a note is derived from the event stream.
It is NOT stored directly -- it is computed by replaying events. The
snapshot file (Section 4.3) persists this derived state for fast
startup, but the snapshot is disposable.

A note in materialised state MUST conform to the following structure:

```json
{
  "id": "note-a1b2c3d4",
  "title": "Example Note Title",
  "body": "Markdown content of the note.",
  "tags": ["project", "draft"],
  "created": "2026-03-31T10:00:00.000Z",
  "modified": "2026-03-31T14:22:07.831Z",
  "created_by": "device-laptop",
  "modified_by": "device-phone",
  "links": [
    { "target": "note-e5f6a7b8", "relation": "references" }
  ],
  "archived": false
}
```

#### 2.1.1 Field Definitions

| Field       | Type             | Required | Description                                                      |
|-------------|------------------|:--------:|------------------------------------------------------------------|
| id          | String           | YES      | Unique identifier. Format: `note-<8hex>`. Generated on creation. |
| title       | String           | YES      | Human-readable title. MAY be empty string.                       |
| body        | String           | YES      | Note content in Markdown format. MAY be empty string.            |
| tags        | Array\<String\>  | YES      | Free-form classification tags. MAY be empty array.               |
| created     | String           | YES      | ISO 8601 timestamp of creation.                                  |
| modified    | String           | YES      | ISO 8601 timestamp of last modification.                         |
| created_by  | String           | YES      | Device ID of the device that created this note.                  |
| modified_by | String           | YES      | Device ID of the device that last modified this note.            |
| links       | Array\<Link\>    | YES      | Links to other notes. MAY be empty array.                        |
| archived    | Boolean          | YES      | Whether this note is archived. Default `false`.                  |

#### 2.1.2 Link Object

| Field    | Type   | Required | Description                                                       |
|----------|--------|:--------:|-------------------------------------------------------------------|
| target   | String | YES      | The `note-<8hex>` ID of the linked note.                          |
| relation | String | YES      | A free-form string describing the relationship (e.g. "references", "follows-up", "related-to"). |


### 2.2 Note ID Generation

Note IDs MUST be generated as `note-<8hex>` where `<8hex>` is 8
lowercase hexadecimal characters. The hex value SHOULD be derived from
a combination of the current timestamp and a random component.
Generated on the creating device.

Implementations MUST ensure uniqueness within a single note
collection. Collision probability is negligible for personal note
collections (4.3 billion possible IDs), but implementations SHOULD
check for collisions and regenerate if one is detected.

---

## 3. Events


### 3.1 Event Structure

Each note event MUST conform to the following structure:

```json
{
  "id": "evt-a1b2c3d4",
  "t": "2026-03-31T14:22:07.831Z",
  "op": "edit",
  "device": "device-laptop",
  "note": "note-e5f6a7b8",
  "data": {
    "title": "Updated Title"
  }
}
```

#### 3.1.1 Field Definitions

| Field  | Type   | Required | Description                                                      |
|--------|--------|:--------:|------------------------------------------------------------------|
| id     | String | YES      | Unique identifier. Format: `evt-<8hex>`. Generated on creation.  |
| t      | String | YES      | ISO 8601 timestamp with timezone. When the event occurred.       |
| op     | String | YES      | The operation type (see Section 3.2).                            |
| device | String | YES      | Device ID of the device that originated this event.              |
| note   | String | YES      | The `note-<8hex>` ID of the affected note.                       |
| data   | Object | YES      | Operation-specific payload (see Section 3.2). MAY be empty object `{}` for operations that carry no payload. |


### 3.2 Event Types

A conforming implementation MUST support all of the following event
types:

| Op        | Data Payload                                | Description                                     |
|-----------|---------------------------------------------|-------------------------------------------------|
| `create`  | `{ "title": str, "body": str, "tags": [str] }` | Create a new note. `title` and `body` are REQUIRED. `tags` is OPTIONAL (defaults to `[]`). |
| `edit`    | `{ "title"?: str, "body"?: str }`           | Update title and/or body. Partial update: only fields present in `data` are changed. At least one of `title` or `body` MUST be present. |
| `delete`  | `{}`                                        | Permanently delete a note. The note MUST NOT appear in materialised state after this event. |
| `archive` | `{ "archived": bool }`                      | Archive (`true`) or unarchive (`false`) a note. |
| `tag`     | `{ "tags": [str] }`                         | Add one or more tags. Tags already present MUST be silently ignored (idempotent). |
| `untag`   | `{ "tags": [str] }`                         | Remove one or more tags. Tags not present MUST be silently ignored (idempotent). |
| `link`    | `{ "target": str, "relation": str }`        | Create a link to another note. `target` MUST be a valid `note-<8hex>` ID. If the link already exists (same target and relation), the event MUST be silently ignored. |
| `unlink`  | `{ "target": str }`                         | Remove a link to another note. Removes ALL links to the given target, regardless of relation. If no link exists, the event MUST be silently ignored. |

An implementation MAY define additional event types for
application-specific purposes. Unknown event types MUST be preserved
during replay and MUST NOT cause errors.

#### 3.2.1 Create Event Example

```json
{
  "id": "evt-00a1b2c3",
  "t": "2026-03-31T10:00:00.000Z",
  "op": "create",
  "device": "device-laptop",
  "note": "note-a1b2c3d4",
  "data": {
    "title": "Meeting Notes",
    "body": "# Q2 Planning\n\n- Budget review\n- Roadmap discussion",
    "tags": ["meeting", "q2"]
  }
}
```

#### 3.2.2 Edit Event Example

```json
{
  "id": "evt-1f2e3d4c",
  "t": "2026-03-31T14:30:00.000Z",
  "op": "edit",
  "device": "device-phone",
  "note": "note-a1b2c3d4",
  "data": {
    "body": "# Q2 Planning\n\n- Budget review\n- Roadmap discussion\n- Action items added after meeting"
  }
}
```

#### 3.2.3 Tag and Link Event Examples

```json
{
  "id": "evt-2a3b4c5d",
  "t": "2026-03-31T15:00:00.000Z",
  "op": "tag",
  "device": "device-laptop",
  "note": "note-a1b2c3d4",
  "data": { "tags": ["action-items", "important"] }
}
```

```json
{
  "id": "evt-3b4c5d6e",
  "t": "2026-03-31T15:05:00.000Z",
  "op": "link",
  "device": "device-laptop",
  "note": "note-a1b2c3d4",
  "data": { "target": "note-e5f6a7b8", "relation": "follows-up" }
}
```


### 3.3 Event Size

Events MUST fit within an R2-WIRE frame. The event metadata (all
fields except the note body content within `data`) MUST NOT exceed 256
bytes when serialised as CBOR.

For `create` and `edit` operations, the note body is potentially large.
When the body exceeds 256 bytes, it MUST be carried on the R2-WIRE
data plane as a separate payload, not inline in the event frame. For
small edits where the complete event (including body) fits within 256
bytes, the body MAY be included inline.

Implementations MUST support note bodies up to 1 MiB. Bodies larger
than 1 MiB are OPTIONAL.


### 3.4 Event ID Generation

Event IDs MUST be generated as `evt-<8hex>` where `<8hex>` is 8
lowercase hexadecimal characters derived from a combination of the
current timestamp and a random component. Implementations MUST ensure
uniqueness within a single event log. Collisions are statistically
negligible (4.3 billion possible IDs) but implementations SHOULD check
for collisions and regenerate if necessary.

---

## 4. Storage Layout


### 4.1 File Structure

All note data resides under `<data_dir>/`. The directory structure
MUST conform to the following layout:

```
<data_dir>/
  events/
    2026-03-30.jsonl     <- yesterday's events (immutable)
    2026-03-31.jsonl     <- today's events (append-only)
  state/
    notes.json           <- materialised current state (all notes)
    snapshot.timestamp    <- when the snapshot was last taken
  index/
    by_tag.json          <- tag -> list of note IDs
    by_date.json         <- date -> list of note IDs modified that day
```

Implementations MUST create the `events/`, `state/`, and `index/`
directories if they do not exist on first write.


### 4.2 Event Log Format

Event log files use JSONL format (JSON Lines): one complete JSON object
per line, separated by newlines. Each line is a complete note event
conforming to the structure defined in Section 3.1.

Event log files are **append-only**. An implementation MUST NOT modify
or delete lines from an existing event log file. New events are
appended to the end of the file for the current day.

Event log files are **day-partitioned**. The filename MUST be the ISO
8601 date (YYYY-MM-DD) followed by `.jsonl`. An event with timestamp
`2026-03-31T14:22:07.831Z` MUST be written to
`events/2026-03-31.jsonl`.

Each line MUST be valid JSON. Implementations MUST NOT write partial
lines. If a write is interrupted, the partial line MUST be detected and
discarded on the next read (lines that fail JSON parsing SHOULD be
logged as warnings and skipped).

**Example file** (`events/2026-03-31.jsonl`):

```
{"id":"evt-00a1b2c3","t":"2026-03-31T10:00:00.000Z","op":"create","device":"device-laptop","note":"note-a1b2c3d4","data":{"title":"Meeting Notes","body":"# Q2 Planning","tags":["meeting"]}}
{"id":"evt-1f2e3d4c","t":"2026-03-31T14:30:00.000Z","op":"edit","device":"device-phone","note":"note-a1b2c3d4","data":{"body":"# Q2 Planning\n\nUpdated after meeting."}}
{"id":"evt-2a3b4c5d","t":"2026-03-31T15:00:00.000Z","op":"tag","device":"device-laptop","note":"note-a1b2c3d4","data":{"tags":["action-items"]}}
```

Event log files for past days (before today) MUST be treated as
immutable. An implementation MUST NOT append to a past-day file under
normal operation. Compaction (Section 7) is the sole exception.


### 4.3 Snapshots (Materialised State)

The `state/notes.json` file contains the materialised current state of
all notes as a JSON array. Each element conforms to the note structure
defined in Section 2.1.

```json
[
  {
    "id": "note-a1b2c3d4",
    "title": "Meeting Notes",
    "body": "# Q2 Planning\n\nUpdated after meeting.",
    "tags": ["meeting", "action-items"],
    "created": "2026-03-31T10:00:00.000Z",
    "modified": "2026-03-31T15:00:00.000Z",
    "created_by": "device-laptop",
    "modified_by": "device-laptop",
    "links": [],
    "archived": false
  }
]
```

Snapshots are **derived** from the event log and exist solely for fast
startup. If the snapshot is lost, corrupted, or outdated, it MUST be
rebuilt by replaying the event log from the beginning.

The `state/snapshot.timestamp` file contains a single ISO 8601
timestamp indicating when the snapshot was last written. On startup,
the implementation MUST:

1. Load the snapshot from `state/notes.json`.
2. Read `state/snapshot.timestamp` to determine the snapshot age.
3. Replay all events from event log files dated on or after the
   snapshot timestamp.
4. Apply those events to the in-memory state to bring it up to date.

If `state/snapshot.timestamp` does not exist or is unparseable, the
implementation MUST rebuild state from scratch by replaying ALL events.

Snapshot files are NOT the source of truth. They are a performance
optimisation. An implementation that ignores snapshots entirely and
always replays from the event log is conforming (though slow for large
collections).


### 4.4 Indexes

Index files are lightweight JSON lookup tables for fast queries. They
exist to avoid scanning every note when filtering by tag or date. They
are **rebuildable** -- if lost or corrupted, the implementation MUST
reconstruct them by scanning the event log or the materialised state.

#### 4.4.1 Tag Index (`index/by_tag.json`)

```json
{
  "meeting": ["note-a1b2c3d4", "note-f0e1d2c3"],
  "action-items": ["note-a1b2c3d4"],
  "project": ["note-f0e1d2c3"]
}
```

Maps each tag string to a sorted list of note IDs that currently carry
that tag. Updated whenever a `create`, `tag`, `untag`, or `delete`
event is applied.

#### 4.4.2 Date Index (`index/by_date.json`)

```json
{
  "2026-03-31": ["note-a1b2c3d4"],
  "2026-03-30": ["note-f0e1d2c3", "note-a1b2c3d4"]
}
```

Maps each date (YYYY-MM-DD) to a list of note IDs that were modified
on that day (based on event timestamps). Updated whenever any event is
applied.

Index files SHOULD be small (typically under 1 MB even for large
personal note collections). Implementations SHOULD update indexes on
every write (after the event is appended to the log).

---

## 5. State Materialisation


### 5.1 Startup Procedure

On startup, a conforming implementation MUST reconstruct current note
state using the following procedure:

1. If `state/notes.json` exists AND `state/snapshot.timestamp` exists
   and is parseable:
   a. Load all notes from `state/notes.json` into an in-memory map
      keyed by note ID.
   b. Read the timestamp from `state/snapshot.timestamp`.
   c. Identify all event log files (`events/*.jsonl`) with dates on
      or after the snapshot date.
   d. Replay those events in chronological order, applying each to
      the in-memory map.
2. If either file is missing or corrupted:
   a. Start with an empty in-memory map.
   b. Replay ALL event log files in chronological order (by filename
      date, then by line order within each file).
3. The in-memory map now represents the current state of all notes.

If `index/by_tag.json` or `index/by_date.json` is missing or
corrupted, the implementation MUST rebuild the affected index from the
current in-memory state.


### 5.2 On Event (Runtime)

When a new event is generated or received, the implementation MUST
perform the following steps in order:

1. **Apply** the event to the in-memory note state.
2. **Append** the event as a single JSON line to today's event log
   file (`events/<YYYY-MM-DD>.jsonl`).
3. **Update** indexes (`by_tag.json`, `by_date.json`) to reflect the
   change.
4. **Mark** the snapshot as dirty (stale).

Step 2 MUST be durable -- the implementation SHOULD call `fsync` or
equivalent after appending to ensure the event is persisted. If the
process crashes after step 1 but before step 2, the event is lost and
MUST be re-applied on next startup from the event log (which will not
contain it). This is acceptable: the event log is the source of truth,
not in-memory state.

#### 5.2.1 Applying Events to State

The following rules govern how each event type modifies the in-memory
note state:

| Op        | Effect on State                                                                  |
|-----------|----------------------------------------------------------------------------------|
| `create`  | Insert a new note with the given ID, title, body, and tags. Set `created` and `modified` to the event timestamp. Set `created_by` and `modified_by` to the event device. Set `links` to `[]` and `archived` to `false`. If a note with the same ID already exists, the event MUST be silently ignored. |
| `edit`    | Update the note's `title` and/or `body` with the values present in `data`. Update `modified` to the event timestamp and `modified_by` to the event device. If the note does not exist, the event MUST be silently ignored. |
| `delete`  | Remove the note from the in-memory map entirely. If the note does not exist, the event MUST be silently ignored. |
| `archive` | Set the note's `archived` field to the value of `data.archived`. Update `modified` and `modified_by`. If the note does not exist, the event MUST be silently ignored. |
| `tag`     | Append each tag in `data.tags` to the note's `tags` array, skipping duplicates. Update `modified` and `modified_by`. If the note does not exist, the event MUST be silently ignored. |
| `untag`   | Remove each tag in `data.tags` from the note's `tags` array, skipping tags not present. Update `modified` and `modified_by`. If the note does not exist, the event MUST be silently ignored. |
| `link`    | Append a link object `{ "target": data.target, "relation": data.relation }` to the note's `links` array, unless a link with the same target and relation already exists. Update `modified` and `modified_by`. If the note does not exist, the event MUST be silently ignored. |
| `unlink`  | Remove all link objects from the note's `links` array where `target` equals `data.target`. Update `modified` and `modified_by`. If the note does not exist, the event MUST be silently ignored. |

Events referencing a non-existent note (except `create`) MUST be
silently ignored during replay. This handles the case where a `delete`
event preceded an `edit` event from another device.


### 5.3 Snapshot Refresh

The implementation SHOULD periodically write the current in-memory
state to the snapshot files. A conforming implementation MUST write the
snapshot on graceful shutdown. The refresh procedure is:

1. Serialise the in-memory note map as a JSON array to
   `state/notes.json`.
2. Write the current ISO 8601 timestamp to
   `state/snapshot.timestamp`.

The implementation SHOULD write to a temporary file and atomically
rename to the target path to prevent corruption from interrupted
writes.

Snapshot refresh frequency is implementation-defined. RECOMMENDED:
every 5 minutes of idle time, or on graceful shutdown, whichever comes
first.

---

## 6. Conflict Resolution


### 6.1 Last-Write-Wins

When two devices produce events affecting the same note concurrently
(i.e. without having seen each other's events), the event with the
later timestamp wins. This is simple and sufficient for personal notes
where the user is typically the only author.

During replay, events are applied in timestamp order. The last `edit`
to arrive sets the title and body. Tags and links are accumulated
(add/remove operations are commutative and idempotent by design).


### 6.2 Event Ordering

Events MUST be ordered by the `t` (timestamp) field. When replaying
events from multiple sources (e.g. after syncing with another device),
all events MUST be sorted by timestamp before replay.

If two events have identical timestamps (sub-second collision), the
implementation MUST use the `device` field as a lexicographic
tiebreaker. If both timestamp and device are identical, the
implementation MUST use the `id` field as a final tiebreaker.


### 6.3 Delete Wins

A `delete` event always wins over concurrent edits. If a note is
deleted on one device while being edited on another, the delete takes
effect. After a `delete` event is applied, subsequent events
referencing that note ID MUST be silently ignored (per Section 5.2.1).

This is a deliberate design choice: deletion is a destructive,
intentional act. The user who deleted a note meant to delete it. An
edit from another device that has not yet seen the deletion SHOULD NOT
resurrect the note.

---

## 7. Compaction


### 7.1 Purpose

The event log grows indefinitely. Compaction reclaims space by removing
old event log files that are fully captured in a snapshot.


### 7.2 Procedure

1. Write a fresh snapshot (Section 5.3).
2. Identify all event log files with dates strictly before the
   snapshot timestamp's date.
3. Those files MAY be deleted or compressed.

Compaction MUST NOT delete event log files dated on or after the
snapshot date.


### 7.3 Retention

The retention period is configurable. The default SHOULD be 90 days
of full event history. Event log files older than the retention period
MAY be purged, provided a snapshot exists that post-dates them.

An implementation MAY compress old event log files (e.g. gzip) instead
of deleting them, to preserve full history at reduced cost. Compressed
files MUST use the naming convention `<YYYY-MM-DD>.jsonl.gz`.

---

## 8. Wire Encoding

When events are transmitted between devices over the R2 network (via
relay or direct connection), the following encoding rules apply:


### 8.1 CBOR Encoding

Events transmitted on the wire MUST be encoded as R2-CBOR Standard
mode, as defined in R2-CBOR. The JSON event structure maps directly to
CBOR with the following field-name-to-integer key mapping for
compactness:

| JSON Field | CBOR Key |
|------------|----------|
| id         | 1        |
| t          | 2        |
| op         | 3        |
| device     | 4        |
| note       | 5        |
| data       | 6        |

Implementations MUST accept both integer-keyed and string-keyed CBOR
maps when decoding. Implementations MUST emit integer-keyed maps when
encoding for transmission.


### 8.2 Encryption

Events MUST be encrypted with the trust group DEK (Data Encryption
Key) as defined in R2-TRUST before transmission. An event MUST NOT be
sent in plaintext over the wire.


### 8.3 Framing

Events are framed as R2-WIRE event frames. The event class MUST be
`r2.capability.notekeeper`.


### 8.4 Data Plane Separation

Note body content (the `body` field within `data` for `create` and
`edit` operations) that exceeds 256 bytes MUST be carried on the
R2-WIRE data plane as a separate payload, not inline in the event
frame. The event frame carries only the metadata; the body is
referenced by the event ID and retrieved from the data plane.

Small bodies (256 bytes or fewer) MAY be included inline in the event
frame for efficiency.

---

## 9. Conformance

A conforming implementation of NK-DATA:

1. MUST store all mutations as events conforming to Section 3.1.
2. MUST support all event types defined in Section 3.2.
3. MUST use append-only, day-partitioned JSONL files for the event log
   (Section 4.2).
4. MUST materialise current note state from the event stream
   (Section 5).
5. MUST apply events to state according to the rules in Section 5.2.1.
6. MUST order events by timestamp during replay (Section 6.2).
7. MUST treat `delete` as winning over concurrent edits (Section 6.3).
8. MUST silently ignore events referencing non-existent notes (except
   `create`).
9. MUST preserve unknown event types during replay without error
   (Section 3.2).
10. MUST rebuild snapshots and indexes from the event log if they are
    missing or corrupted (Sections 4.3, 4.4).
11. MUST encode events as R2-CBOR Standard mode for wire transmission
    (Section 8.1).
12. MUST encrypt events with the trust group DEK before wire
    transmission (Section 8.2).
13. MUST use the event class `r2.capability.notekeeper` for R2-WIRE
    framing (Section 8.3).
14. MUST write snapshots on graceful shutdown (Section 5.3).
15. MUST NOT modify or delete lines from existing event log files
    except during compaction (Section 7).
16. SHOULD support note bodies up to 1 MiB.
17. SHOULD default to 90-day event log retention (Section 7.3).
18. SHOULD call `fsync` or equivalent after appending events to the
    log (Section 5.2).

---

*End of NK-DATA v0.1 Draft*
