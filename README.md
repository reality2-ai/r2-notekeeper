# Notekeeper

<p align="center">
  <img src="icons/notekeeper.svg" width="96" alt="Notekeeper">
</p>

<p align="center">
  Private notes on your <a href="https://reality2-ai.github.io">Reality2</a> mesh.<br>
  End-to-end encrypted. No server. No cloud. No account.<br><br>
  <a href="https://reality2-ai.github.io/r2-notekeeper/conformance.html"><img src="https://img.shields.io/badge/R2_conformance-110%2F110_pass-brightgreen" alt="R2 conformance: 110/110 pass"></a>
</p>

Notekeeper runs entirely in your web browser. Your notes are encrypted with keys that never leave your devices. A [relay](https://github.com/reality2-ai/r2-relay) connects your devices to each other - but it can't read your notes.

## Getting Started

### What you need

1. A modern web browser (any browser that supports WebAssembly - which is all of them these days)
2. A relay running somewhere (see below)

### Step 1: Relay

The relay connects your devices to each other. Without a relay, Notekeeper works fine on a single device - but to sync notes between your laptop and phone, they need a relay to find each other.

**The community relay is pre-filled** - you don't need to do anything. Notekeeper defaults to `wss://relay.reality2.ai/r2`, which is free to use and can't read your data (it only forwards encrypted bytes).

**Want to run your own?** See the [Relay](https://github.com/reality2-ai/r2-relay) page. You can switch to your own relay at any time in Settings.

### Step 2: Open Notekeeper

Open [Notekeeper](https://reality2-ai.github.io/r2-notekeeper/) in your browser. You'll see a screen asking you to create or join a trust group.

### Step 3: Create or join a trust group

A trust group is your private space. Only devices in the group can see your notes.

**Starting fresh?** Enter a device name, the relay address, and click **Create New Notekeeper**. This creates a new trust group just for you.

**Already have a trust group** from another R2 capability (like Anthill or TrustTalk)? You don't need a new one - join the existing group using an invitation code from any device that's already a member. Your notes will share the same trust group and the same devices.

### Step 4: Add another device

Want your notes on your phone or another computer too?

1. Open **Settings** (top right)
2. Click **Generate Invitation**
3. You'll see:
   - A **short code** like `a1b2-c3d4-e5f6` - type this on the other device
   - A **QR code** - scan this with a phone camera
   - A **full link** - copy and paste this to the other device

On the other device:

1. Open Notekeeper in a browser
2. Paste the invitation (the full link, or type the short code)
3. Enter the relay address (same as before)
4. Click **Join Trust Group**

Both devices are now in the same trust group. Notes sync automatically through the relay.

### Step 5: Write notes

- Click **+ New** to create a note
- Write in Markdown - use the formatting toolbar or type it directly
- Toggle between **Edit** and **Preview** to see the rendered result
- Notes auto-save after 10 seconds of inactivity, or press **Ctrl+S** / click **Sync**
- Changes sync to your other devices through the relay

## Features

- **Markdown editing** with formatting toolbar (headings, bold, italic, code, lists, links)
- **Auto-save** after 10 seconds of typing pause
- **End-to-end encrypted sync** - notes encrypted before leaving your device
- **Works offline** - notes persist in your browser; syncs when relay is available
- **Light and dark themes** - follows your system preference, or set manually in Settings
- **QR code invitations** - scan to add a device to your trust group
- **Mobile friendly** - works on phones, tablets, and desktops
- **Installable** - add to home screen on any device for a native-like experience

## Privacy

- Your notes are encrypted before they leave your browser
- The relay forwards encrypted bytes - it cannot read your notes
- There is no account, no server-side storage, no analytics, no tracking
- Trust group keys are stored in your browser's local storage
- Clearing your browser data will remove your trust group membership - you would need to rejoin from another device

## Common Questions

### I opened Notekeeper in a different browser and had to join again. Why?

Each browser keeps its own separate storage. Different browsers don't share data with each other - even on the same computer. A private/incognito window is also separate. Each one is a different "device" as far as Notekeeper is concerned.

This is by design. Your trust group keys are stored in the browser that created them. If any browser could access another browser's keys, that would be a security problem.

To use Notekeeper in a new browser, join the trust group from there - open Settings on a browser that's already a member, generate an invitation, and use it in the new browser. Your notes will sync across.

---

### I cleared my browser data (or uninstalled the browser) and lost my trust group. Can I get back in?

If you have another device still in the trust group, yes - generate a new invitation from that device and rejoin. Your notes will sync back from the other device through the relay.

If all your devices have been cleared, the trust group is gone. There is no password recovery, no server with a backup, no "forgot my account" flow. The keys existed only on your devices.

This is the trade-off of true privacy: no one can recover your data for you, because no one else ever had it. This is why it's a good idea to have Notekeeper on more than one device - each one is a backup of the other.

---

### Can I use Notekeeper without a relay?

Yes - for notes on a single device. You can create a trust group, write notes, and they'll persist in your browser. You just won't be able to sync to other devices without a relay connecting them.

---

### Can other people read my notes if they run the relay?

No. The relay forwards encrypted bytes. It doesn't have your trust group keys and cannot decrypt anything that passes through it. Even if someone captures all the traffic, they see only ciphertext.

---

### I'm getting an error about insecure WebSocket connections

If you're using Notekeeper from `https://` (like GitHub Pages) and your relay is on `ws://` (not encrypted), the browser will block the connection. This is a browser security rule - HTTPS pages can't make insecure connections.

**Solutions:**
- **For local relays:** `ws://localhost:21042/r2` works from HTTPS - browsers allow localhost as an exception
- **For remote relays:** set up TLS on your relay (put nginx or caddy in front) and use `wss://` instead of `ws://`
- **For testing:** run Notekeeper locally over HTTP (`python3 -m http.server 21045` in the r2-notekeeper directory) - then `ws://` works fine

---

### Can I use an existing trust group from another R2 capability?

Yes. A trust group is not tied to any single capability. If you already have a trust group from Anthill, TrustTalk, or any other R2 tool, you can join that same group in Notekeeper. Your notes will be accessible on all the devices that are already members - no need to invite them again.

Just use an invitation code from any device in the existing group, and join from the Notekeeper screen.

---

### Can I just bookmark it?

Yes - that's the simplest way to use Notekeeper. Bookmark the page, come back anytime. Your trust group membership and notes are stored in your browser and will be there when you return. You don't need to install it as an app unless you want the full-screen experience and home screen icon.

The only thing that would lose your data is clearing your browser's site data for this page (or using private/incognito mode, which doesn't keep anything after the window closes).

---

### Can I make Notekeeper into an app on my phone or computer?

Yes. In most browsers, you can install Notekeeper so it appears alongside your other apps:

- **iPhone/iPad (Safari):** Tap the share button, then "Add to Home Screen"
- **Android (Chrome, Brave, Edge):** Tap the three-dot menu, then "Add to Home screen" or "Install app"
- **Chrome/Brave/Edge on desktop:** Click the install icon in the address bar, or go to the three-dot menu and choose "Install Notekeeper"
- **Firefox on desktop:** Not directly installable as PWA, but bookmarking works perfectly
- **macOS (Safari):** File menu, then "Add to Dock"

Once installed, Notekeeper opens in its own window without browser chrome - it looks and feels like a regular app.

---

### Does it work offline?

Your notes are always available offline - they're stored in your browser's local storage. You can read and edit them without any internet connection.

What requires connectivity is **syncing between devices**. When you edit a note offline, the changes are saved locally. Next time the relay is reachable, your changes sync to your other devices automatically.

If you install Notekeeper as an app (see above), the page itself is cached too - so it loads instantly even without internet.

---

## How it works

Notekeeper is built with the Reality2 protocol stack, compiled to WebAssembly (70KB). When you open the page, the R2 stack loads in your browser and your browser becomes a node in your mesh.

- **Trust group** - your devices share a cryptographic identity
- **Events** - each note operation (create, edit, delete) produces a signed R2 event
- **Encrypted content** - note text is encrypted with the trust group's data key before being sent through the relay
- **Persistence** - trust group membership and notes stored in your browser's local storage

## Licence

MIT OR Apache-2.0

---

Part of [Reality2](https://reality2-ai.github.io) - your digital life, under your control.
