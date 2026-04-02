# R2 Notekeeper

Private notes on the [Reality2](https://reality2-ai.github.io) mesh. End-to-end encrypted. No server. No cloud. No account.

Notekeeper runs entirely in your web browser. Your notes are encrypted with keys that never leave your devices. A [relay](https://github.com/reality2-ai/r2-relay) connects your devices to each other — but it can't read your notes.

## Getting Started

### What you need

1. A web browser (Chrome, Edge, Firefox, or Safari)
2. A relay running somewhere (see below)

### Step 1: Set up a relay

The relay connects your devices to each other across the internet. You need one running before you can sync notes between devices.

**If someone has already set up a relay for you**, they'll give you an address like `ws://relay.example.com:21042/r2`. Skip to Step 2.

**To run your own relay**, see the [R2 Relay guide](https://github.com/reality2-ai/r2-relay). The short version:

```
git clone https://github.com/reality2-ai/r2-relay.git
cd r2-relay
cargo run --release
```

Your relay address will be `ws://your-machine:21042/r2`.

### Step 2: Open Notekeeper

Open the Notekeeper page in your browser. You'll see a screen asking you to create or join a trust group.

### Step 3: Create a trust group

A trust group is your private space. Only devices you add can see your notes.

1. Enter a name for this device (e.g. "My Laptop")
2. Enter the relay address (e.g. `ws://your-machine:21042/r2`)
3. Click **Create New Notekeeper**

You're in. Start writing.

### Step 4: Add another device

Want your notes on your phone or another computer too?

1. Open **Settings** (top right)
2. Click **Generate Invitation**
3. You'll see:
   - A **short code** like `a1b2-c3d4-e5f6` — type this on the other device
   - A **QR code** — scan this with a phone camera
   - A **full link** — copy and paste this to the other device

On the other device:

1. Open Notekeeper in a browser
2. Paste the invitation (the full link, or type the short code)
3. Enter the relay address (same as before)
4. Click **Join Trust Group**

Both devices are now in the same trust group. Notes sync automatically through the relay.

### Step 5: Write notes

- Click **+ New** to create a note
- Write in Markdown — use the formatting toolbar or type it directly
- Toggle between **Edit** and **Preview** to see the rendered result
- Notes auto-save after 10 seconds of inactivity, or press **Ctrl+S** / click **Sync**
- Changes sync to your other devices through the relay

## Features

- **Markdown editing** with formatting toolbar (headings, bold, italic, code, lists, links)
- **Auto-save** after 10 seconds of typing pause
- **End-to-end encrypted sync** — notes encrypted before leaving your device
- **Works offline** — notes persist in your browser; syncs when relay is available
- **Light and dark themes** — follows your system preference, or set manually in Settings
- **QR code invitations** — scan to add a device to your trust group
- **Mobile friendly** — works on phones, tablets, and desktops
- **Installable** — add to home screen on any device for a native-like experience

## Privacy

- Your notes are encrypted before they leave your browser
- The relay forwards encrypted bytes — it cannot read your notes
- There is no account, no server-side storage, no analytics, no tracking
- Trust group keys are stored in your browser's local storage
- Clearing your browser data will remove your trust group membership — you would need to rejoin from another device

## How it works

Notekeeper is built with the Reality2 protocol stack, compiled to WebAssembly (70KB). When you open the page, the R2 stack loads in your browser and your browser becomes a node in the mesh.

- **Trust group** — your devices share a cryptographic identity
- **Events** — each note operation (create, edit, delete) produces a signed R2 event
- **Encrypted content** — note text is encrypted with the trust group's data key before being sent through the relay
- **Persistence** — trust group membership and notes stored in your browser's local storage

## Licence

MIT OR Apache-2.0

---

Part of [Reality2](https://reality2-ai.github.io) — your digital life, under your control.
