# R2 Notekeeper

A distributed notetaking capability for [Reality2](https://reality2.ai) trust groups.

**Dr Roy C. Davies**
[roycdavies.github.io](https://roycdavies.github.io) | [roy.c.davies@ieee.org](mailto:roy.c.davies@ieee.org)

---

## What is this?

Notekeeper is a **swarm of R2 sentants** that provides distributed notetaking across all devices in a trust group. Create a note on your phone, it appears on your laptop. Edit on your laptop, it propagates to your tablet. No central server, no Tailscale, no third-party accounts.

Notes are Markdown files synced via R2 events through a lightweight cloud relay. R2-TRUST provides end-to-end encryption — the relay cannot read your notes.

**This is not an app.** It is a capability — a swarm definition (R2-DEF) that loads sentants, binds existing R2 plugins, and exposes a web UX.

## Why?

Notekeeper exists to validate the R2 distributed stack before building more complex capabilities like [Anthill](https://github.com/reality2-ai/anthill). It exercises:

- **R2-TRUST** — trust groups, device provisioning, end-to-end encryption
- **R2-WIRE** — event protocol (<256 bytes)
- **R2-TRANSPORT** — WebSocket binding
- **Cloud relay** — NAT traversal without Tailscale or any VPN
- **Temporal event store** — the same pattern used by Anthill's knowledge graphs

Every lesson learned here feeds directly into the Anthill rebuild.

## Architecture

```
Swarm: "notekeeper"
├── Sentant: note-store (r2.capability.notekeeper)
│   Manages notes — create, edit, delete, tag, link
│   In-memory state backed by temporal event log (JSONL)
│
├── Sentant: sync-agent (r2.capability.sync)
│   Propagates events between devices in the trust group
│   Handles offline catchup on reconnect
│
├── Plugins: r2-transport, r2-trust (existing R2 infrastructure)
│
└── UX: Phoenix PWA (Markdown editor, search, graph view)
```

Relay (separate swarm, runs on cloud hive):
```
Sentant: relay (r2.capability.relay)
  Routes R2-WIRE frames between devices
  Stateless, untrusted — cannot read your notes
  Buffers recent events for device catchup
```

## Specifications

| Spec | Covers |
|------|--------|
| [NK-INTRO](specs/NK-INTRO.md) | Vision, architecture, R2 stack usage |
| [NK-DATA](specs/NK-DATA.md) | Note model, events, temporal storage |
| [NK-RELAY](specs/NK-RELAY.md) | Cloud relay protocol, mDNS discovery, NAT traversal |
| [NK-UX](specs/NK-UX.md) | Phoenix PWA, Markdown editor, sync indicators |

## License

**Dual licensed:**

- **AGPL-3.0-or-later** — free for open source projects.
- **Commercial license** — contact [Dr Roy C. Davies](mailto:roy.c.davies@ieee.org).

Copyright (c) 2024-2026 Dr Roy C. Davies. All rights reserved.
