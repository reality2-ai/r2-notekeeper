# NK-UX: Notekeeper User Experience

| Field      | Value                            |
|------------|----------------------------------|
| Version    | 0.1 Draft                        |
| Date       | 2026-03-31                       |
| Status     | Draft                            |
| Depends on | NK-INTRO, NK-DATA, R2-GQL       |
| Related    | NK-RELAY, R2-PROVISION           |

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
> "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
> document are to be interpreted as described in RFC 2119.

---

## 1. Introduction

The Notekeeper UX is a Progressive Web App served by Phoenix. It provides a
clean, responsive interface for creating, editing, searching, and linking
notes. It works on phone, tablet, and desktop — install as a home screen app
for a native-like experience.

The UX communicates with local sentants via Phoenix channels (real-time) and
R2-GQL (queries and mutations). It does not communicate with the relay
directly — that is the sync-agent's job.

### 1.1 Design Principles

1. **Local-first** — the UX talks to local sentants, not a remote server.
2. **Real-time** — changes from other devices appear immediately via Phoenix
   channel subscriptions.
3. **Offline-capable** — the PWA service worker caches the app shell; notes
   are viewable from local state.
4. **Simple** — this is a notepad, not a CMS. Clean, fast, focused.
5. **Responsive** — a single layout that adapts across phone, tablet, and
   desktop.

---

## 2. Layout

### 2.1 Structure

The interface comprises three regions:

- **Sidebar** — a scrollable list of notes (filterable by tag, searchable)
  with a create button at the top.
- **Main area** — the note editor (Markdown) or note viewer.
- **Bottom bar** (mobile only) — quick actions: new note, search, tags.

### 2.2 Responsive Behaviour

An implementation MUST adapt to the following breakpoints:

| Breakpoint          | Sidebar          | Main area      | Graph panel |
|---------------------|------------------|----------------|-------------|
| Mobile (<768px)     | Hidden; swipe or hamburger to reveal | Full width | Hidden |
| Tablet (768–1200px) | Visible, narrow  | Split view     | Hidden      |
| Desktop (>1200px)   | Visible          | Editor         | OPTIONAL side panel |

On mobile, the sidebar MUST overlay the main area rather than push it off
screen. The bottom bar MUST be rendered only on viewports narrower than
768px.

---

## 3. Note Editor

### 3.1 Editing

The editor MUST provide:

1. A **title field** at the top of the main area.
2. A **body textarea** supporting Markdown input.
3. A **toolbar** with at minimum: bold, italic, heading, link, list, and
   code-block buttons.
4. A **preview mode** — either split-pane or toggle — rendering Markdown to
   HTML.

The implementation SHOULD default to the editing mode and MUST allow
switching to preview without losing unsaved content.

### 3.2 Auto-Save

The editor MUST auto-save after a debounced delay of no more than one second
following the last keystroke. Auto-save generates an edit event delivered to
the sync-agent. There is no explicit "save" button.

### 3.3 Tags

1. Tag chips MUST appear below the title field.
2. A tag input field MUST allow the user to type and add tags.
3. Each chip MUST include a remove affordance (e.g. an "x" icon).
4. The tag input SHOULD provide autocomplete from the set of existing tags.

### 3.4 Links

1. Typing `[[note title]]` in the body MUST create a link to the named
   note.
2. A link button in the toolbar SHOULD open a search dialog for selecting a
   target note.
3. In preview mode, links MUST render as clickable references that navigate
   to the target note.
4. A **Connections** section below the editor SHOULD display all notes
   linked to or from the current note.

---

## 4. Note List

### 4.1 Sidebar List

The sidebar MUST display notes sorted by last-modified date, most recent
first. Each entry MUST show:

- Title (truncated if necessary).
- First line of the body as a preview.
- Last-modified date.
- Tag chips.

The sidebar MUST provide:

1. A **"New Note"** button at the top.
2. A **search field** that filters notes by title and body text. Filtering
   MAY be performed client-side.
3. **Tag filtering** — clicking a tag chip MUST filter the list to notes
   carrying that tag.

### 4.2 Archive

1. Archived notes MUST be hidden from the default list.
2. A "Show archived" toggle MUST reveal archived notes.
3. Archived notes SHOULD appear visually distinct (e.g. greyed out).

---

## 5. Graph View

### 5.1 Purpose

A 2D force-directed graph showing how notes link to each other. This is
simpler than the Anthill 3D knowledge graph — 2D is sufficient for note
links.

### 5.2 Rendering

The graph MUST render:

- **Nodes** — note titles, sized by number of connections.
- **Edges** — links between notes, labelled with the relation string.

The graph SHOULD:

1. Colour nodes by tag (the most prominent tag determines colour).
2. Navigate to the target note when a node is clicked.
3. Show the note title and tag chips on hover.

### 5.3 Library

Implementations SHOULD use d3-force (2D). Using a 3D library (e.g.
ForceGraph3D) is NOT RECOMMENDED — it adds weight without benefit for this
use case.

### 5.4 Visibility

On desktop viewports (>1200px), the graph MAY be shown as an optional side
panel alongside the editor. On smaller viewports, the graph SHOULD be
accessible via a dedicated view or tab.

---

## 6. Device Provisioning

### 6.1 First Device

When no trust group exists, the UX MUST present two options:

1. **Create a new trust group** — generates a colony key, displays a QR
   code and a text join code. The join code MUST include the relay address.
2. **Join an existing trust group** — proceeds to the joining flow
   (Section 6.2).

### 6.2 Joining

To join an existing trust group, the user MUST be able to:

1. Scan a QR code, or
2. Enter a text join code manually.

On submission, the UX MUST initiate the R2-TRUST provisioning flow (device
credential exchange). On success, notes MUST sync from the existing device.

### 6.3 Device Management

A settings page MUST list all devices in the trust group, showing for each:

- Device name.
- Last seen timestamp.
- Joined date.

The page MUST allow revoking a device's access, which removes its
credential from the trust group.

---

## 7. Sync Indicators

### 7.1 Connection Status

The UX MUST display a persistent connection indicator with the following
states:

| State       | Colour | Meaning                        |
|-------------|--------|--------------------------------|
| Connected   | Green  | Connected via relay or direct  |
| Connecting  | Orange | Attempting reconnection        |
| Offline     | Red    | No connectivity                |

A tooltip or long-press SHOULD show: connection mode (direct or relay), peer
count, and last sync time.

### 7.2 Sync Activity

1. When events arrive from other devices, the affected note in the sidebar
   SHOULD briefly flash or pulse.
2. New notes from other devices SHOULD appear at the top of the list with a
   "new" badge.
3. Edits from other devices MUST update the note in real-time if the user is
   currently viewing it.

---

## 8. Real-Time Updates

### 8.1 Phoenix Channel

The UX MUST subscribe to the `notekeeper:events` Phoenix channel on
connection. Incoming events MUST be applied to local state immediately.

If the user is editing a note that receives an edit event from another
device, the UX MUST show a non-blocking notification (e.g. "Updated by
[device name]") and MUST NOT interrupt the user's typing or discard their
unsaved changes.

### 8.2 Conflict Display

When a note has been edited on two devices while offline and the edits have
been merged (last-write-wins), the note SHOULD display a subtle "merged"
indicator. No conflict resolution UI is required — the user can review the
merged result and edit further.

---

## 9. Theme

1. The UX MUST support light and dark themes.
2. The default theme MUST match the operating system preference
   (`prefers-color-scheme`).
3. A toggle in the header MUST allow manual override.
4. The chosen theme MUST be persisted to `localStorage`.

---

## 10. PWA

### 10.1 Manifest

The UX MUST serve a valid web app manifest at `GET /manifest.json`
containing at minimum: app name, icons, theme colour, and
`display: "standalone"`.

### 10.2 Service Worker

A service worker MUST be registered at `GET /sw.js`. It MUST cache:

1. The app shell (HTML, CSS, JavaScript).
2. Current note state for offline viewing.

### 10.3 Offline Behaviour

When offline, the user MUST be able to view cached notes. Edits made while
offline MUST be queued and synced when connectivity is restored.

### 10.4 Install Prompt

On platforms that support it, the UX SHOULD present an install prompt or
banner.

---

## 11. GraphQL API (R2-GQL)

The UX communicates with the local Notekeeper sentant via the following
GraphQL operations. All operations are defined by R2-GQL; this section
documents the surface the UX depends on.

### 11.1 Queries

```graphql
query { notes(tag: String, search: String): [Note] }
query { note(id: ID!): Note }
query { tags: [TagCount] }
query { devices: [Device] }
```

### 11.2 Mutations

```graphql
mutation { createNote(title: String!, body: String, tags: [String]): Note }
mutation { editNote(id: ID!, title: String, body: String): Note }
mutation { deleteNote(id: ID!): Boolean }
mutation { tagNote(id: ID!, tags: [String]!): Note }
mutation { linkNotes(from: ID!, to: ID!, relation: String!): Note }
mutation { archiveNote(id: ID!, archived: Boolean!): Note }
```

### 11.3 Subscriptions

```graphql
subscription { noteEvent(id: ID): NoteEvent }
```

The `noteEvent` subscription delivers real-time events for a specific note
(when `id` is provided) or for all notes (when `id` is omitted). This
supplements the Phoenix channel for GraphQL-native clients.

---

## 12. Conformance

### 12.1 REQUIRED

An implementation claiming conformance to NK-UX:

1. MUST serve the UX as a Phoenix-rendered page accessible via a browser.
2. MUST provide a Markdown editor with title, body, toolbar, and preview as
   defined in Section 3.
3. MUST auto-save edits with a debounced delay of no more than one second.
4. MUST display a sidebar note list sorted by last-modified date with
   search and tag filtering.
5. MUST support archive toggling as defined in Section 4.2.
6. MUST render `[[note title]]` syntax as navigable links in preview mode.
7. MUST adapt layout to mobile, tablet, and desktop breakpoints as defined
   in Section 2.2.
8. MUST subscribe to the `notekeeper:events` Phoenix channel and apply
   incoming events to local state.
9. MUST display a connection status indicator with green, orange, and red
   states as defined in Section 7.1.
10. MUST support light and dark themes persisted to `localStorage`.
11. MUST serve a valid PWA manifest and register a service worker.
12. MUST support offline viewing of cached notes.
13. MUST present device provisioning flows (create or join trust group) as
    defined in Section 6.
14. MUST provide device management with revoke capability.
15. MUST show a non-blocking notification when a note is updated by another
    device during editing, without interrupting the user.

### 12.2 RECOMMENDED

1. SHOULD provide tag autocomplete from existing tags.
2. SHOULD provide a 2D force-directed graph view of note links.
3. SHOULD show sync activity indicators (flash, badge) as defined in
   Section 7.2.
4. SHOULD display a "Connections" section below the editor showing linked
   notes.
5. SHOULD support QR code scanning for device provisioning.
6. SHOULD show a "merged" indicator on notes merged after offline edits.

### 12.3 OPTIONAL

1. MAY display the graph view as a side panel on desktop viewports.
2. MAY provide an install prompt banner for PWA installation.
3. MAY perform note search filtering client-side.

---

## 13. References

- RFC 2119. Bradner, S. "Key words for use in RFCs to Indicate Requirement
  Levels." IETF, 1997.
- NK-INTRO — Notekeeper Introduction specification.
- NK-DATA — Notekeeper Data Model specification.
- NK-RELAY — Notekeeper Relay specification.
- R2-GQL — R2 GraphQL API specification.
- R2-PROVISION — R2 Device Provisioning specification.
- Phoenix Framework — https://www.phoenixframework.org
- d3-force — https://github.com/d3/d3-force

---

## Changelog

### 0.1 Draft — 2026-03-31

- Initial draft covering layout, editor, note list, graph view, device
  provisioning, sync indicators, real-time updates, theme, PWA, and GraphQL
  API surface.
