# NK-RELAY: Cloud Relay and Device Connectivity

| Field      | Value                                                        |
|------------|--------------------------------------------------------------|
| Version    | 0.1 Draft                                                    |
| Date       | 2026-03-31                                                   |
| Status     | Draft                                                        |
| Depends on | R2-TRUST, R2-WIRE, R2-TRANSPORT                              |
| Related    | NK-INTRO, R2-INTERNET, R2-BEACON                             |

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
> "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
> document are to be interpreted as described in RFC 2119.

---

## 1. Introduction

The cloud relay provides NAT traversal for R2 devices without third-party
VPN services.  All devices connect OUTBOUND to a relay -- no port
forwarding, no firewall configuration, no accounts.  R2-TRUST provides
end-to-end encryption; the relay is untrusted and cannot read the traffic.

This is the specification that replaces Tailscale with R2-native
connectivity.  Where ANTHILL-FEDERATION section 2.2.1 describes the relay as a
future transport evolution, this specification defines the protocol in
full.  Every R2 application -- Notekeeper, Anthill, and any future
capability -- uses this same relay protocol for NAT traversal.

### 1.1 Design Principles

1. **Outbound only** -- all connections are initiated by the device, never
   inbound.  No port forwarding is required on any device.

2. **Relay is untrusted** -- the relay routes opaque R2-WIRE frames.  It
   cannot read, modify, or forge the content.  End-to-end encryption via
   R2-TRUST ensures confidentiality even if the relay is compromised.

3. **Relay is stateless** -- the relay holds no persistent data.  It
   buffers only recent events (bounded by count and time) to support
   catchup for reconnecting devices.

4. **No accounts** -- trust group identity (the colony key) is the only
   identity needed.  There are no user accounts, no email addresses, no
   passwords, no OAuth tokens.

5. **Commodity infrastructure** -- run your own relay on a $5/month VPS,
   or share one.  The relay is a single-binary Elixir release (~20 MB)
   that runs on any Linux, macOS, or FreeBSD server.

6. **Local-first** -- on the same LAN, devices connect directly via mDNS
   discovery.  The relay is a fallback for when direct connections are
   unavailable.

### 1.2 Terminology

| Term                | Definition                                                                                                  |
|---------------------|-------------------------------------------------------------------------------------------------------------|
| Relay               | A server that accepts outbound WebSocket connections from R2 devices and routes R2-WIRE frames between them. |
| Cloud Relay         | A relay running on a public server (cloud VPS) to enable NAT traversal.                                     |
| Direct Connection   | A WebSocket connection between two devices on the same LAN, bypassing the relay.                            |
| Outbound Connection | A connection initiated by the device to the relay or peer.  Devices NEVER accept inbound connections.       |
| Event Buffer        | A bounded in-memory ring buffer on the relay holding recent R2-WIRE frames per trust group.                 |
| Catchup             | The process by which a reconnecting device receives missed events from the relay buffer or a peer.          |
| Trust Group Hash    | The hex-encoded SHA-256 hash of the trust group's public key, used as a routing identifier on the relay.    |
| Device Credential   | An Ed25519 key pair issued to a device at provisioning time (R2-TRUST, R2-PROVISION).                       |
| Heartbeat           | A periodic liveness signal exchanged between a device and the relay (or between peers).                     |
| mDNS Discovery      | Multicast DNS service discovery used to find peer devices on the local network (R2-BEACON).                 |

---

## 2. Connectivity Model

### 2.1 Three Connection Modes

A device MUST support three connection modes.  The mode is transparent to
sentants -- they send and receive R2 events regardless of transport.

1. **Direct (same LAN)** -- devices discover each other via mDNS and
   connect directly via WebSocket.  Lowest latency.  R2-TRUST
   authenticates the connection end-to-end.

2. **Cloud relay (across NAT)** -- devices connect outbound to a known
   relay endpoint.  The relay routes R2-WIRE frames between devices that
   share the same trust group hash.  The relay cannot read the frames.

3. **Offline (no connectivity)** -- the device operates locally.  Events
   are queued in the local event log.  On reconnect, the device performs
   catchup to reconcile state with the trust group.

### 2.2 Connection Priority

Devices SHOULD prefer direct connections when available.  The priority
order is:

1. Direct connection (mDNS-discovered peer on same LAN).
2. Cloud relay (configured relay endpoint).
3. Offline (no connectivity available).

If a direct connection fails or the peer is not discoverable via mDNS,
the device MUST fall back to the cloud relay.  If the relay is also
unreachable, the device MUST operate in offline mode.

Connection mode MUST be transparent to the sentants.  A sentant emits
an event; the transport layer delivers it via whichever path is available.
The sentant MUST NOT need to know whether the event was delivered directly,
via relay, or queued for later delivery.

### 2.3 Concurrent Paths

A device MAY maintain both a relay connection and one or more direct
connections simultaneously.  When multiple paths exist:

- Events MUST be sent via all active paths.
- Events received via multiple paths MUST be deduplicated by event ID
  before delivery to sentants.
- If a direct connection is established while a relay connection is
  active, the device SHOULD continue using both paths for redundancy.
  The device MAY drop the relay connection if all trust group peers are
  reachable directly.

---

## 3. Cloud Relay Protocol

### 3.1 Relay Endpoint

The relay MUST listen for WebSocket connections on a known address
(e.g., `wss://relay.example.com/r2`).

- The relay MUST use TLS (WSS) for all connections.  Plain WebSocket
  (WS) MUST NOT be used in production.  Plain WS MAY be used for
  localhost development only.
- The TLS layer protects the transport.  R2-TRUST protects the content
  end-to-end.  These are independent layers -- both are REQUIRED.
- The relay MUST support WebSocket protocol version 13 (RFC 6455).

### 3.2 Connection Handshake

The connection handshake authenticates the device to the relay and
registers it for event routing within its trust group.

**Step 1: WebSocket upgrade.**
The device opens a WSS connection to the relay endpoint.

**Step 2: HELLO message.**
Immediately after WebSocket upgrade, the device MUST send a HELLO
message:

```json
{
  "type": "hello",
  "trust_group": "<hex-encoded SHA-256 hash of trust group public key>",
  "device_id": "<hex-encoded Ed25519 device public key>",
  "timestamp": 1711756800,
  "signature": "<hex-encoded HMAC-SHA256 of 'trust_group:device_id:timestamp'>"
}
```

Field definitions:

| Field         | Type   | Description                                                                |
|---------------|--------|----------------------------------------------------------------------------|
| `type`        | string | MUST be `"hello"`.                                                         |
| `trust_group` | string | Hex-encoded SHA-256 hash of the trust group's Ed25519 public key.          |
| `device_id`   | string | Hex-encoded Ed25519 public key of the connecting device.                   |
| `timestamp`   | uint64 | Current time as Unix seconds (UTC).                                        |
| `signature`   | string | Hex-encoded HMAC-SHA256 computed over the concatenation `trust_group:device_id:timestamp` using the device's private key as the HMAC key. |

**Step 3: Relay verification.**
The relay MUST verify the HELLO message:

1. Verify that `timestamp` is within 60 seconds of the relay's current
   time.  If not, the relay MUST reject the connection with WebSocket
   close code 4403 (Timestamp Rejected) and a reason string indicating
   clock skew.
2. Verify the `signature` by computing the expected HMAC-SHA256 using
   the device's public key (from `device_id`).  If the signature is
   invalid, the relay MUST reject the connection with WebSocket close
   code 4401 (Unauthorized).
3. If verification succeeds, the relay adds the connection to its
   routing table under the `trust_group` hash.

**Step 4: WELCOME response.**
On successful verification, the relay MUST respond:

```json
{
  "type": "welcome",
  "peers": 2,
  "buffer_depth": 1000
}
```

| Field          | Type   | Description                                                         |
|----------------|--------|---------------------------------------------------------------------|
| `type`         | string | MUST be `"welcome"`.                                                |
| `peers`        | uint32 | Number of OTHER devices currently connected for this trust group.   |
| `buffer_depth` | uint32 | Maximum number of events the relay buffers per trust group.         |

If the device does not receive a WELCOME within 10 seconds of sending
HELLO, the device MUST close the connection and retry with exponential
backoff.

### 3.3 Relay Does NOT Verify Trust Group Membership

The relay verifies only that the connecting device holds the private key
corresponding to the `device_id` it claims (via the HMAC signature).
The relay does NOT verify that the device is a legitimate member of the
trust group -- that verification is R2-TRUST's responsibility and
happens end-to-end between devices.

The relay is a dumb router.  It routes frames to all connections sharing
the same `trust_group` hash.  If an attacker connects with a valid key
pair but is not actually a trust group member, the attacker will receive
encrypted frames it cannot decrypt (because it lacks the trust group's
Data Encryption Key).  R2-TRUST section 3 defines the DEK distribution
mechanism that ensures only provisioned devices hold the DEK.

### 3.4 Event Routing

Once a device is connected and authenticated:

1. The device sends R2-WIRE frames to the relay as WebSocket binary
   messages.
2. The relay MUST forward the frame to ALL other connections registered
   under the same `trust_group` hash.
3. The relay MUST NOT forward the frame back to the sender.
4. The relay MUST NOT parse, decrypt, decompress, or modify the frame
   in any way.  Frames are opaque byte sequences.
5. The relay MUST NOT drop frames silently.  If a frame cannot be
   delivered to a peer (e.g., the peer's send buffer is full), the relay
   SHOULD close that peer's connection so the peer reconnects and
   performs catchup.

Frame size limits:

- The relay MUST accept frames up to 64 KiB.  This accommodates
  R2-WIRE extended frames carrying plugin data plane content.
- The relay SHOULD reject frames larger than 64 KiB with WebSocket
  close code 4413 (Frame Too Large).

### 3.5 Heartbeat

The heartbeat mechanism detects dead connections.

- Devices MUST send a heartbeat every 30 seconds:
  ```json
  { "type": "ping" }
  ```
- The relay MUST respond to each heartbeat:
  ```json
  { "type": "pong" }
  ```
- If the relay receives no message of any kind (heartbeat, event frame,
  or control message) from a device within 90 seconds (3x the heartbeat
  interval), the relay MUST close the connection.
- If the device receives no PONG within 90 seconds, the device MUST
  consider the connection dead and reconnect.

The 30-second heartbeat interval is consistent with R2-TRANSPORT
section 6.1 and ANTHILL-FEDERATION section 4.5.

### 3.6 Reconnection

On connection loss, the device MUST attempt reconnection with
exponential backoff:

```
Delays: 1s, 2s, 4s, 8s, 16s, 32s, 60s, 60s, 60s, ...
```

- The backoff base is 1 second.
- Each subsequent attempt doubles the delay.
- The backoff cap is 60 seconds.
- Reconnection attempts MUST continue indefinitely.  The relay may
  restart, or network connectivity may return at any time.
- On successful reconnection, the device MUST perform the full
  handshake (section 3.2) and SHOULD request catchup (section 3.7).
- Jitter: implementations SHOULD add random jitter of up to 25% of the
  delay to avoid thundering herd when many devices reconnect
  simultaneously.

### 3.7 Event Buffer and Catchup

The relay SHOULD maintain an in-memory ring buffer of recent events per
trust group.  This buffer enables devices that reconnect after a brief
disconnection to catch up without requiring a full peer-to-peer sync.

**Buffer parameters:**

| Parameter            | Default | Description                                        |
|----------------------|---------|----------------------------------------------------|
| `event_buffer_size`  | 1000    | Maximum number of events buffered per trust group.  |
| `buffer_ttl`         | 3600    | Maximum age (seconds) of buffered events.           |

Events older than `buffer_ttl` seconds SHOULD be evicted even if the
buffer is not full.

**Catchup protocol:**

**Step 1:** After receiving WELCOME, the device MAY send a CATCHUP
request:

```json
{
  "type": "catchup",
  "since": 1711756200
}
```

| Field   | Type   | Description                                               |
|---------|--------|-----------------------------------------------------------|
| `type`  | string | MUST be `"catchup"`.                                      |
| `since` | uint64 | Unix timestamp (seconds) of the last event received by this device. |

**Step 2:** The relay replays all buffered events for this trust group
with timestamps greater than `since`, in chronological order.  Each
replayed event is sent as a WebSocket binary message (the original
opaque R2-WIRE frame).

**Step 3:** After replaying all buffered events, the relay sends a
CATCHUP_COMPLETE message:

```json
{
  "type": "catchup_complete",
  "events_sent": 42,
  "oldest_buffered": 1711756000
}
```

| Field             | Type   | Description                                                |
|-------------------|--------|------------------------------------------------------------|
| `type`            | string | MUST be `"catchup_complete"`.                              |
| `events_sent`     | uint32 | Number of events replayed.                                 |
| `oldest_buffered` | uint64 | Unix timestamp of the oldest event in the buffer.          |

**Step 4:** If the device's `since` timestamp is older than
`oldest_buffered`, the relay's buffer is insufficient.  The relay
indicates this by setting `events_sent` to the number of events it
could provide and `oldest_buffered` to the oldest available timestamp.
The device MUST then perform a full peer-to-peer sync (section 5.2) to
obtain events older than `oldest_buffered`.

### 3.8 Relay Discovery

How does a device know which relay to connect to?

The relay address is embedded in the join code or QR code used during
device provisioning (R2-PROVISION).  The format is:

```
relay:wss://relay.example.com/r2|code:xxxx-xxxx-xxxx
```

- The first device (trust group creator) configures the relay address
  at trust group creation time.
- All subsequent devices learn the relay address during provisioning.
- The relay address MUST be stored in the device's local configuration.
- If the relay address changes (e.g., migration to a different server),
  the trust group owner MUST issue new join codes with the updated
  address.  Existing devices MUST be reconfigured manually or via a
  `relay_update` event (section 3.9).

### 3.9 Relay Address Update

A trust group owner MAY broadcast a relay address change to all devices
by emitting an R2-WIRE event:

```
Event name: relay.update
Payload (CBOR):
  new_url : text  -- new relay WSS URL
  migrate_after : uint64  -- Unix timestamp after which to use the new relay
```

On receiving this event, each device MUST:

1. Store the new relay address in local configuration.
2. After `migrate_after`, connect to the new relay instead of the old
   one.
3. Maintain the old relay connection until `migrate_after` to avoid
   message loss during migration.

### 3.10 Control Messages Summary

The following table summarises all control messages exchanged between
device and relay.  R2-WIRE frames are binary messages; control messages
are JSON text messages.

| Message             | Direction        | Format | Description                                   |
|---------------------|------------------|--------|-----------------------------------------------|
| `hello`             | Device -> Relay  | JSON   | Authentication handshake.                     |
| `welcome`           | Relay -> Device  | JSON   | Handshake accepted; peer count.               |
| `ping`              | Device -> Relay  | JSON   | Heartbeat.                                    |
| `pong`              | Relay -> Device  | JSON   | Heartbeat response.                           |
| `catchup`           | Device -> Relay  | JSON   | Request buffered events since timestamp.      |
| `catchup_complete`  | Relay -> Device  | JSON   | Catchup replay finished.                      |
| R2-WIRE frame       | Device <-> Relay | Binary | Opaque encrypted event frame (routed).        |

### 3.11 WebSocket Close Codes

The relay defines the following application-specific WebSocket close
codes:

| Code | Name               | Meaning                                                  |
|------|--------------------|----------------------------------------------------------|
| 4401 | Unauthorized       | HELLO signature verification failed.                     |
| 4403 | Timestamp Rejected | HELLO timestamp outside acceptable window (>60s skew).   |
| 4408 | Heartbeat Timeout  | No message received within 90 seconds.                   |
| 4413 | Frame Too Large    | R2-WIRE frame exceeds 64 KiB.                            |
| 4429 | Rate Limited       | Device is sending frames faster than the relay allows.   |

---

## 4. Direct Connection (LAN)

When devices are on the same local network, they SHOULD connect directly
to minimise latency and avoid relay dependency.

### 4.1 mDNS Discovery

Devices MUST advertise their presence on the local network using mDNS
(R2-BEACON):

- **Service type:** `_r2._tcp.local`
- **TXT records:**
  - `tg=<first 8 hex characters of trust group hash>` -- enables
    devices to filter for peers in the same trust group without
    revealing the full hash.
  - `v=1` -- protocol version for forward compatibility.
- **Port:** the port on which the device's local WebSocket listener is
  accepting connections.

Devices MUST listen for mDNS advertisements from other devices.  When a
device discovers a peer advertising the same trust group prefix:

1. The device SHOULD attempt a direct connection (section 4.2).
2. If the trust group prefix matches but the full trust group hash
   (exchanged during handshake) does not match, the connection MUST be
   rejected.

### 4.2 Direct Connection Handshake

1. The discovering device opens a WebSocket connection to the peer's
   advertised address and port.
2. The connecting device sends a HELLO message (same format as
   section 3.2, but with the full trust group hash and device
   credential).
3. The receiving device verifies the HELLO and additionally verifies
   trust group membership via R2-TRUST (unlike the relay, which skips
   this step).
4. The receiving device responds with a WELCOME message.
5. Both devices exchange their current event log state (vector clocks or
   latest timestamps) to determine what events each side is missing.
6. Events flow bidirectionally without a relay intermediary.

### 4.3 Direct Connection Authentication

Direct connections MUST be authenticated end-to-end via R2-TRUST device
credential exchange.  Unlike the relay (which only verifies key
ownership), a direct peer MUST verify that the connecting device is a
provisioned member of the trust group.

The authentication flow:

1. Connecting device presents `device_id` and `signature` in HELLO.
2. Receiving device checks `device_id` against its local trust group
   membership list (the set of provisioned device public keys).
3. If the `device_id` is not in the membership list, the connection MUST
   be rejected with WebSocket close code 4401.
4. If the `device_id` is in the membership list, the signature is
   verified and the connection is accepted.

### 4.4 Dual Path Operation

A device MAY maintain both a relay connection and one or more direct
connections simultaneously.  When operating in dual-path mode:

- Outbound events MUST be sent via all active paths (relay AND direct).
- Inbound events MUST be deduplicated by event ID before delivery to
  sentants.  Each R2-WIRE event carries a unique event ID; the
  transport layer MUST maintain a seen-set of recent event IDs (bounded
  by time and count) for deduplication.
- The seen-set SHOULD retain event IDs for at least 5 minutes to handle
  delayed relay delivery.

---

## 5. Offline Operation

### 5.1 Local Event Queue

When no connectivity is available (neither relay nor direct):

1. Events emitted by local sentants MUST be written to the local event
   log (NK-DATA) as normal.
2. A queue of unsent events MUST be maintained.  This queue MUST be
   persisted to disk so that unsent events survive device restarts.
3. The queue MUST be ordered by event timestamp.
4. On reconnect (to relay or direct peer), all queued events MUST be
   transmitted in order.

### 5.2 Catchup on Reconnect

When connectivity is restored, the device MUST perform catchup to
receive events it missed while offline:

**Step 1:** Reconnect to the relay (section 3.6) or discover peers via
mDNS (section 4.1).

**Step 2:** Request catchup from the relay buffer (section 3.7).

**Step 3:** If the relay buffer is insufficient (the device was offline
longer than the buffer window), the device MUST perform a full
peer-to-peer sync:

1. The device sends a SYNC_REQUEST to a connected peer:
   ```json
   {
     "type": "sync_request",
     "since": 1711750000,
     "device_id": "<hex-encoded device public key>"
   }
   ```
2. The peer replays all events from its local event log since the
   requested timestamp.
3. The peer sends a SYNC_COMPLETE message when finished:
   ```json
   {
     "type": "sync_complete",
     "events_sent": 350
   }
   ```

**Step 4:** Apply received events to local state.  Conflict resolution
follows last-write-wins semantics as defined in NK-DATA.

**Step 5:** Transmit all locally queued events to the relay and/or
direct peers.

### 5.3 Consistency Guarantee

Notekeeper provides **eventual consistency**.  All devices in a trust
group MUST converge to the same state given sufficient time and
connectivity.  The convergence mechanism is:

- Events are totally ordered by `(timestamp, device_id)` pair.
- Concurrent edits to the same note are resolved by last-write-wins
  on the timestamp.  If timestamps are equal, the lexicographically
  greater `device_id` wins.
- Deleted notes MUST be represented as tombstone events, not by absence.
  Tombstones MUST be retained for at least 30 days before compaction.

---

## 6. Security

### 6.1 End-to-End Encryption

All R2-WIRE frames are encrypted with the trust group's Data Encryption
Key (DEK) as defined in R2-TRUST.  The DEK is distributed only to
provisioned devices during the join flow.

- The relay handles only encrypted bytes.
- Even if the relay is compromised, note content is protected.
- Even if a network observer captures relay traffic (despite TLS), the
  inner R2-TRUST encryption protects content.
- This is defence in depth: TLS protects the transport, R2-TRUST
  protects the content.

### 6.2 Device Authentication

Authentication occurs at two levels:

| Level     | What Is Verified                              | Who Verifies       |
|-----------|-----------------------------------------------|--------------------|
| Relay     | Device holds the private key it claims.       | Relay (HMAC check) |
| End-to-end| Device is a provisioned trust group member.   | Peer device (R2-TRUST membership check) |

The relay provides transport-level authentication (preventing random
connections from consuming relay resources).  True trust group membership
is verified end-to-end by peer devices.

### 6.3 Replay Protection

- The HELLO message includes a `timestamp` field.
- The relay MUST reject HELLO messages with timestamps more than 60
  seconds from the relay's current time.
- R2-WIRE events include sequence numbers and event IDs that prevent
  replay at the application layer.

### 6.4 Relay Operator Threat Model

The relay operator:

| Can                                                | Cannot                                              |
|----------------------------------------------------|-----------------------------------------------------|
| See which trust group hashes are active (metadata). | Read note content (encrypted end-to-end).            |
| See device public keys and connection times.        | Forge events (would need trust group DEK).           |
| See frame sizes and frequency (traffic analysis).   | Add or remove devices from a trust group.            |
| Drop or delay frames (denial of service).           | Decrypt frames (would need trust group DEK).         |
| Buffer and replay frames (but they are encrypted).  | Correlate trust group hashes to real-world identity. |

To mitigate metadata leakage, users who require maximum privacy SHOULD
run their own relay (section 7.4).

### 6.5 Join Code Security

The relay address is embedded in the join code.  Join codes:

- MUST be single-use (consumed on first successful provisioning).
- MUST expire after 5 minutes.
- MUST be generated with at least 48 bits of entropy.
- MUST be transmitted out-of-band (QR code, spoken, written).

An attacker who intercepts a join code can learn the relay address, but
cannot join the trust group without also completing the R2-TRUST
provisioning handshake (which requires approval from the trust group
owner).

---

## 7. Relay Implementation

### 7.1 Relay as R2 Sentant

The relay itself MAY be implemented as an R2 sentant (class:
`r2.capability.relay`).  This is architecturally self-consistent --
the relay is a sentant running on a cloud hive that routes R2-WIRE
frames for other trust groups.

Alternatively, the relay MAY be implemented as a standalone Elixir
process.  The protocol is the same either way.  Implementations MUST
NOT require a specific relay implementation -- any server that speaks
the protocol defined in section 3 is a conforming relay.

### 7.2 Resource Requirements

The relay is designed to be lightweight:

- **CPU:** minimal.  The relay does no computation on frame content --
  it is pure I/O routing.
- **Memory:** proportional to the number of active connections and
  buffered events.  At 1000 events per trust group and 256 bytes per
  event, each trust group requires ~256 KB of buffer memory.
- **Bandwidth:** proportional to event throughput.  The relay forwards
  each frame to N-1 peers, where N is the number of connected devices
  in the trust group.
- **Disk:** none required.  The event buffer is in-memory only.

A single relay instance on a $5/month VPS (1 vCPU, 512 MB RAM) SHOULD
handle at least 1000 concurrent trust groups and 10,000 concurrent
device connections.

### 7.3 Scalability

A single relay can handle thousands of trust groups and tens of
thousands of connections.  For deployments requiring higher scale:

- Multiple relay instances MAY be deployed behind a TCP load balancer.
- Each instance maintains its own connection table and event buffer.
- Devices connect to any instance; the load balancer distributes
  connections.
- All devices in a trust group MUST connect to the SAME relay instance
  for event routing to work.  The load balancer MUST use sticky sessions
  based on the trust group hash (e.g., consistent hashing on the
  `trust_group` query parameter or the first message after connect).
- Cross-instance event routing (allowing devices in the same trust group
  to connect to different instances) is NOT specified in this version.
  It is reserved for future work.

### 7.4 Self-Hosted Relay

Users SHOULD run their own relay for maximum privacy.  A conforming
relay is a single-binary Elixir release that:

1. Listens for WSS connections.
2. Verifies HELLO handshakes.
3. Routes binary frames by trust group hash.
4. Buffers recent events for catchup.
5. Responds to heartbeats.

No other functionality is required.  The relay binary SHOULD be
published as a container image and as a standalone release for common
platforms (Linux amd64, Linux arm64, macOS arm64).

### 7.5 Shared Relay

Multiple trust groups MAY share a single relay.  Trust groups are
isolated by their hash -- the relay routes frames only to connections
with the same trust group hash.  A shared relay operator cannot read
the content of any trust group's events (section 6.4).

A community-operated shared relay MAY be provided as a convenience for
users who do not want to run their own.  The shared relay MUST NOT
require accounts or registration.

---

## 8. Configuration

### 8.1 Device Configuration

```toml
[relay]
url = "wss://relay.example.com/r2"    # relay endpoint
heartbeat_interval = 30               # seconds
reconnect_base = 1                    # seconds (exponential backoff start)
reconnect_cap = 60                    # seconds (exponential backoff maximum)
reconnect_jitter = 0.25               # fraction of delay added as random jitter

[local]
mdns_enabled = true                   # enable mDNS discovery for direct connections
mdns_service = "_r2._tcp.local"       # mDNS service type
direct_port = 3002                    # port for direct LAN WebSocket listener
```

| Field                | Type    | Default                  | Description                                         |
|----------------------|---------|--------------------------|-----------------------------------------------------|
| `relay.url`          | string  | (none)                   | WSS URL of the relay endpoint. REQUIRED.            |
| `relay.heartbeat_interval` | uint16 | `30`              | Heartbeat interval in seconds.                      |
| `relay.reconnect_base`     | uint16 | `1`               | Initial reconnection delay in seconds.              |
| `relay.reconnect_cap`      | uint16 | `60`              | Maximum reconnection delay in seconds.              |
| `relay.reconnect_jitter`   | float  | `0.25`            | Random jitter fraction (0.0 to 1.0).                |
| `local.mdns_enabled`       | bool   | `true`            | Whether to advertise and discover via mDNS.         |
| `local.mdns_service`       | string | `"_r2._tcp.local"` | mDNS service type.                                  |
| `local.direct_port`        | uint16 | `3002`            | Port for the direct connection WebSocket listener.  |

### 8.2 Relay Server Configuration

```toml
[relay]
listen = "0.0.0.0:443"               # bind address
tls_cert = "/path/to/cert.pem"       # TLS certificate
tls_key = "/path/to/key.pem"         # TLS private key
event_buffer_size = 1000             # events per trust group
buffer_ttl = 3600                    # seconds before buffered events expire
max_connections = 10000              # maximum concurrent WebSocket connections
max_frame_size = 65536               # maximum R2-WIRE frame size in bytes (64 KiB)
heartbeat_timeout = 90               # seconds before dropping idle connection
hello_timeout = 10                   # seconds to wait for HELLO after connect
timestamp_tolerance = 60             # seconds of clock skew tolerance for HELLO
```

| Field                     | Type    | Default  | Description                                                |
|---------------------------|---------|----------|------------------------------------------------------------|
| `relay.listen`            | string  | `"0.0.0.0:443"` | Bind address and port.                              |
| `relay.tls_cert`          | string  | (none)   | Path to TLS certificate file. REQUIRED.                    |
| `relay.tls_key`           | string  | (none)   | Path to TLS private key file. REQUIRED.                    |
| `relay.event_buffer_size` | uint32  | `1000`   | Maximum events buffered per trust group.                   |
| `relay.buffer_ttl`        | uint32  | `3600`   | Maximum age of buffered events in seconds.                 |
| `relay.max_connections`   | uint32  | `10000`  | Maximum concurrent WebSocket connections.                  |
| `relay.max_frame_size`    | uint32  | `65536`  | Maximum accepted R2-WIRE frame size in bytes.              |
| `relay.heartbeat_timeout` | uint16  | `90`     | Seconds before closing an idle connection.                 |
| `relay.hello_timeout`     | uint16  | `10`     | Seconds to wait for HELLO after WebSocket upgrade.         |
| `relay.timestamp_tolerance` | uint16 | `60`    | Seconds of clock skew tolerance for HELLO timestamps.      |

---

## 9. Conformance

### 9.1 REQUIRED -- Device

A conforming device implementation MUST:

1. Support all three connection modes (direct, relay, offline) as
   defined in section 2.1.
2. Prefer direct connections over relay connections when both are
   available (section 2.2).
3. Implement the relay handshake protocol including HELLO and WELCOME
   (section 3.2).
4. Send heartbeat messages every 30 seconds (section 3.5).
5. Implement exponential backoff reconnection on connection loss with
   a cap of 60 seconds (section 3.6).
6. Request catchup on reconnection (section 3.7).
7. Deduplicate events received via multiple paths by event ID
   (section 2.3).
8. Encrypt all R2-WIRE frames with the trust group DEK via R2-TRUST
   (section 6.1).
9. Authenticate direct connections via R2-TRUST device credential
   exchange, verifying trust group membership (section 4.3).
10. Persist unsent events to disk for transmission on reconnect
    (section 5.1).
11. Verify peer trust group membership for direct connections
    (section 4.3).
12. Store the relay address received during provisioning (section 3.8).

### 9.2 REQUIRED -- Relay

A conforming relay implementation MUST:

1. Listen for WSS connections on the configured endpoint (section 3.1).
2. Verify HELLO signatures and reject invalid connections with
   appropriate close codes (section 3.2).
3. Reject HELLO timestamps outside the configured tolerance window
   (section 3.2).
4. Route R2-WIRE frames to all other connections with the same trust
   group hash (section 3.4).
5. NOT forward frames back to the sender (section 3.4).
6. NOT parse, decrypt, or modify R2-WIRE frames (section 3.4).
7. Respond to heartbeat pings with pongs (section 3.5).
8. Close connections that miss heartbeats for 90 seconds (section 3.5).
9. Close connections that do not send HELLO within 10 seconds of
   WebSocket upgrade (section 8.2).
10. Enforce the maximum frame size limit (section 3.4).

### 9.3 RECOMMENDED

An implementation SHOULD:

1. Implement the event buffer and catchup protocol (section 3.7).
2. Support relay address updates via the `relay.update` event
   (section 3.9).
3. Add reconnection jitter to avoid thundering herd (section 3.6).
4. Advertise via mDNS for local discovery (section 4.1).
5. Support dual-path operation (relay + direct simultaneously)
   (section 4.4).
6. Run relay on TLS with certificates from a public CA for production
   deployments.
7. Log connection, disconnection, and handshake failure events for
   operational visibility.

### 9.4 OPTIONAL

An implementation MAY:

1. Implement relay clustering for high availability (section 7.3).
2. Implement the relay as an R2 sentant (section 7.1).
3. Support plain WebSocket (WS) for localhost development
   (section 3.1).
4. Provide a community shared relay for convenience (section 7.5).
5. Implement cross-instance event routing for clustered relays
   (future work).

---

## 10. Conjectures

| ID       | Conjecture                                                                                                   | Falsification                                                                                                              |
|----------|--------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| NK-R-001 | Relay forwarding adds less than 50 ms median round-trip latency for events between two devices on broadband. | Measure end-to-end latency from event emission on device A to receipt on device B via relay. If median exceeds 50 ms on broadband, profile the relay path. |
| NK-R-002 | A single $5/month VPS relay handles 1000 concurrent trust groups without performance degradation.            | Connect 1000 trust groups with 2 devices each, each generating 1 event/second. Measure relay CPU and memory. If CPU exceeds 80% or memory exceeds 80%, the conjecture is falsified. |
| NK-R-003 | The event buffer (1000 events, 1 hour TTL) is sufficient for 95% of reconnection scenarios.                  | Measure the distribution of offline durations across real usage. If more than 5% of reconnections require full peer sync, increase the buffer. |
| NK-R-004 | mDNS discovery detects LAN peers within 5 seconds on common home networks.                                   | Test on WiFi networks with consumer routers from 5 vendors. If discovery time exceeds 5 seconds on more than 20% of networks, investigate mDNS reflection issues. |
| NK-R-005 | Dual-path deduplication (relay + direct) does not add measurable CPU overhead on mobile devices.              | Profile deduplication seen-set operations on a Raspberry Pi 4. If CPU usage for deduplication exceeds 1% of total, optimise the seen-set implementation. |

---

## 11. References

- R2-TRUST. Reality2 Trust Group Specification.
- R2-WIRE. Reality2 Wire Protocol Specification.
- R2-TRANSPORT. Reality2 Transport Binding Specification, v0.1. 2026.
- R2-INTERNET. Reality2 Internet Transport Specification, v0.1. 2026.
- R2-BEACON. Reality2 Beacon and Discovery Specification.
- R2-PROVISION. Reality2 Device Provisioning Specification.
- NK-INTRO. Notekeeper Introduction and Architecture, v0.1. 2026.
- NK-DATA. Notekeeper Data Model and Event Log.
- ANTHILL-FEDERATION. Distributed Deployment and Relay Protocol, v0.1. 2026.
- RFC 2119. Bradner, S. "Key words for use in RFCs to Indicate
  Requirement Levels." IETF, 1997.
- RFC 6455. Fette, I. and A. Melnikov. "The WebSocket Protocol."
  IETF, 2011.

---

## Appendix A: Protocol Message Schema (JSON)

```json
// HELLO (device -> relay or device -> peer)
{
  "type": "hello",
  "trust_group": "a1b2c3d4e5f6...",
  "device_id": "f6e5d4c3b2a1...",
  "timestamp": 1711756800,
  "signature": "0123456789abcdef..."
}

// WELCOME (relay -> device or peer -> device)
{
  "type": "welcome",
  "peers": 2,
  "buffer_depth": 1000
}

// PING (device -> relay)
{
  "type": "ping"
}

// PONG (relay -> device)
{
  "type": "pong"
}

// CATCHUP (device -> relay)
{
  "type": "catchup",
  "since": 1711756200
}

// CATCHUP_COMPLETE (relay -> device)
{
  "type": "catchup_complete",
  "events_sent": 42,
  "oldest_buffered": 1711756000
}

// SYNC_REQUEST (device -> peer, for full peer-to-peer sync)
{
  "type": "sync_request",
  "since": 1711750000,
  "device_id": "f6e5d4c3b2a1..."
}

// SYNC_COMPLETE (peer -> device)
{
  "type": "sync_complete",
  "events_sent": 350
}

// RELAY_UPDATE (R2-WIRE event, trust group owner -> all devices)
// Payload is CBOR-encoded within an R2-WIRE frame, shown here as JSON
// for readability:
{
  "event": "relay.update",
  "new_url": "wss://new-relay.example.com/r2",
  "migrate_after": 1711760400
}
```

---

## Appendix B: Connection State Machine

### B.1 Device Connection States

```
disconnected --> connecting --> handshaking --> connected --> disconnected
                     |                              |
                     +-- backoff_wait <-------------+
```

| State          | Description                                                               |
|----------------|---------------------------------------------------------------------------|
| `disconnected` | No active connection.  Device operates in offline mode.                   |
| `connecting`   | WebSocket upgrade in progress.                                            |
| `handshaking`  | WebSocket open; HELLO sent; awaiting WELCOME.                             |
| `connected`    | Authenticated and routing events.  Heartbeats active.                     |
| `backoff_wait` | Connection failed or lost; waiting before next reconnection attempt.       |

Transitions:

| From           | To             | Trigger                                                    |
|----------------|----------------|------------------------------------------------------------|
| `disconnected` | `connecting`   | Device starts or connectivity becomes available.           |
| `connecting`   | `handshaking`  | WebSocket upgrade succeeds.                                |
| `connecting`   | `backoff_wait` | WebSocket upgrade fails (network error, DNS failure).      |
| `handshaking`  | `connected`    | WELCOME received.                                          |
| `handshaking`  | `backoff_wait` | HELLO rejected (4401, 4403) or WELCOME timeout (10s).     |
| `connected`    | `disconnected` | Heartbeat timeout or WebSocket close.                      |
| `backoff_wait` | `connecting`   | Backoff timer expires.                                     |

---

## Appendix C: Revision History

| Version | Date       | Changes                                                                                              |
|---------|------------|------------------------------------------------------------------------------------------------------|
| 0.1     | 2026-03-31 | Initial draft -- relay protocol, direct connections, offline operation, security model, configuration |
