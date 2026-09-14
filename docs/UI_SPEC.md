# TailDeck — UI Specification

Companion to [`ARCHITECTURE.md`](ARCHITECTURE.md). This document is the pixel-level contract: four
screens, their states, and the navigation between them.

**What changed from the mockup.** The mockup's *Service View* had a horizontal tab strip
(`Omaipai | Dipsy | Server | Code | +`). You cut it, so **there is no tab strip**: the grid is the
switcher, which makes the keep-alive pool load-bearing rather than a nicety. The Edit screen's
**"Show in top bar"** toggle consequently had nothing to control and is now **"Pin to top of grid"**.

**A correction made after first use.** The first build took "just the WebView" literally and shipped
no chrome at all. That survived exactly one session: with no reload there is no way out of a page
that has wedged, short of closing the session from the grid, and with no back button the only exit is
the system gesture. §3 now specifies a slim toolbar — back, forward, title, reload, overflow — and
that is what the app ships. The floating back pill survives as an option, off by default.

---

## Contents

1. [Design tokens](#1-design-tokens)
2. [Screen 1 — Home](#2-screen-1--home)
3. [Screen 2 — Service View](#3-screen-2--service-view)
4. [Screen 3 — Edit Service](#4-screen-3--edit-service)
5. [Screen 4 — Settings](#5-screen-4--settings)
6. [Shared components](#6-shared-components)
7. [Navigation map](#7-navigation-map)
8. [Motion](#8-motion)
9. [Accessibility](#9-accessibility)
10. [Copy deck](#10-copy-deck)
11. [Responsive rules](#11-responsive-rules)

---

## 1. Design tokens

### Colour

Dark only in v1, matching the mockup's near-black surfaces and violet primary.

| Token | Hex | Used for |
|---|---|---|
| `bg` | `#0A0E13` | app background, WebView background |
| `surface` | `#151A21` | cards, fields, banner |
| `surfaceHigh` | `#1C232C` | pressed states, sheets, icon tiles |
| `border` | `#232B36` | card outline, dividers |
| `borderDashed` | `#2E3846` | unconfigured card outline |
| `textPrimary` | `#F2F5F8` | titles, names |
| `textSecondary` | `#8B95A5` | subtitles, labels, URLs |
| `textDisabled` | `#5A6472` | ghost slots |
| `primary` | `#6C5CE7` | Save button, progress line, focus ring |
| `primaryPressed` | `#5B4BD6` | Save pressed |
| `success` | `#22C55E` | online dot, "Tailscale Connected" |
| `warning` | `#F5A524` | VPN up but services down |
| `danger` | `#EF4444` | offline dot, delete |
| `iconTint` | accent @ 14% | icon tile background |

Each service also carries its own **accent** colour (12 choices) used for its icon tile and its
offline-state tint. Default accents seeded per service so the grid looks alive, exactly as in the
mockup (green for Omaipai, blue for Dipsy, orange for the server, indigo for the code server, …).

### Type

System font (Roboto). Addresses use a monospaced face so digits align in the grid.

| Role | Size | Weight | Notes |
|---|---|---|---|
| Screen title | 28 | 600 | "TailDeck" |
| Screen subtitle | 14 | 400 | `textSecondary` |
| Section header | 13 | 600 | letterSpacing 0.4, uppercase, `textSecondary` |
| Card name | 15 | 600 | maxLines 1, ellipsis |
| Card address | 11 | 400 | **mono**, `textSecondary`, maxLines 1 |
| Banner | 14 | 500 | |
| Field label | 13 | 500 | `textSecondary` |
| Field input | 16 | 400 | URL field is mono |
| Helper / error | 12 | 400 | `textSecondary` / `danger` |
| Button | 16 | 600 | |

### Shape and space

| Token | Value |
|---|---|
| Card radius | 18 |
| Icon tile radius | 14 (card) / 22 (edit screen) |
| Field radius | 14 |
| Button radius | 14 |
| Sheet radius | 20 top |
| Pill radius | 999 |
| Grid gap | 14 |
| Screen padding | 16 |
| Card padding | 14 |
| Minimum touch target | 48 × 48 |

---

## 2. Screen 1 — Home

The default screen. Fixed **2 columns × 5 rows = 10 slots**, never scrolls, never paginates.

```
┌──────────────────────────────────────────────┐
│                                              │  ← SafeArea top, padding 16/8
│  TailDeck                              ⚙    │  ← 28/600                    48dp gear
│  Your private services, anywhere             │  ← 14/400 textSecondary
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ ●  Tailscale Connected             ›   │  │  ← banner, 52dp, radius 16
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌───────────────────┐ ┌───────────────────┐ │
│  │ ┌─────┐        ⋮  │ │ ┌─────┐        ⋮  │ │  ← row 1
│  │ │  🤖 │           │ │ │  🐋 │           │ │
│  │ └─────┘           │ │ └─────┘           │ │
│  │ Omaipai         ● │ │ Dipsy Carness   ● │ │
│  │ 100.114.10.5:3000 │ │ 100.114.10.6:8080 │ │
│  └───────────────────┘ └───────────────────┘ │
│                                              │
│  ┌───────────────────┐ ┌───────────────────┐ │
│  │ ┌─────┐        ⋮  │ │ ┌─────┐        ⋮  │ │  ← row 2
│  │ │  🖥 │           │ │ │  ⌨ │           │ │
│  │ └─────┘           │ │ └─────┘           │ │
│  │ My Server       ● │ │ Code Server     ● │ │
│  │ 100.114.10.7:22   │ │ 100.114.10.8:8080 │ │
│  └───────────────────┘ └───────────────────┘ │
│                                              │
│                    ⋮   rows 3, 4   ⋮         │
│                                              │
│  ┌───────────────────┐ ┌───────────────────┐ │
│  │        ＋         │ │                   │ │  ← row 5
│  │   Add Service     │ │   (ghost slot)    │ │
│  │  Tap to configure │ │                   │ │
│  └───────────────────┘ └───────────────────┘ │
└──────────────────────────────────────────────┘
```

### 2.1 Header

- `TailDeck` left-aligned, `Your private services, anywhere` beneath it.
- Gear icon, top-right, 24px glyph in a 48dp target, `textSecondary`, `surfaceHigh` circular
  background at 40% — matches the mockup's subtle treatment. Opens Settings.
- Not a `SliverAppBar`. It is page content, so it scrolls nothing and stays fixed.

### 2.2 Tailscale banner

Full-width, `surface`, radius 16, 52dp tall, 16dp horizontal padding. Tap → re-run all probes
(shows a 700 ms spinner on the leading dot).

| State | Leading | Text | Trailing | Text colour |
|---|---|---|---|---|
| `connected` | ● `success` | Tailscale Connected | `›` | `textPrimary` |
| `checking` | ◌ spinner | Checking connections… | — | `textSecondary` |
| `vpnOff` | ● `danger` | Tailscale appears off | `Retry` | `danger` |
| `servicesDown` | ● `warning` | VPN up, services not responding | `Retry` | `warning` |
| `allDisabled` | ● `textDisabled` | Connection checks are off | — | `textSecondary` |

Sub-line under the text on `vpnOff` / `servicesDown` (12sp, `textSecondary`):
"Turn on the VPN, then tap Retry." / "Is the service running on your PC?"

### 2.3 Service card

Fixed `childAspectRatio` ≈ 1.15, radius 18, `surface`, 1px `border`, 14dp padding, `RepaintBoundary`.

```
┌───────────────────────┐
│ ┌─────┐            ⋮  │   icon tile 44×44, radius 14, accent@14% bg, 24px glyph
│ │  ◉  │               │   overflow: 24px glyph, 48dp target, textSecondary @45%
│ └─────┘               │
│                       │   ← 10dp gap
│ Omaipai            ●  │   name 15/600, flex; status dot 8dp
│ 100.114.10.5:3000     │   address 11 mono, textSecondary
└───────────────────────┘
```

**States**

| State | Treatment |
|---|---|
| normal | as above |
| pressed | scale 0.97, `surfaceHigh` background, 90 ms |
| online | dot `success`; address shows latency instead when a probe is fresh: `100.114.10.5:3000 · 82 ms` |
| offline | dot `danger`; icon tile desaturated to 40% opacity |
| checking | dot replaced by an 8dp spinner, `textSecondary` |
| unconfigured | dashed `borderDashed` border, `＋` centred, name = service name, subtitle = "Tap to configure", no overflow menu, no dot |
| probe disabled | dot `textDisabled`, no latency |
| ghost | `surface` at 40%, no content — keeps the 10-slot rhythm visible |

**Interactions**

- Tap → activate the session (`registry.acquire`) and show the Service View.
- Tap on `unconfigured` → go straight to Edit.
- Long-press **or** `⋮` → overflow bottom sheet, both routes identical.

**Overflow sheet** (`surfaceHigh`, radius 20 top, drag handle, safe-area padded):

| Row | Action |
|---|---|
| Edit | Edit screen |
| Test connection | inline probe, toast with result |
| Open in browser | `ACTION_VIEW` on the URL |
| Duplicate | copy with a new id, `(copy)` suffix, next free slot |
| Close session | evict from the pool; enabled only when the session is live; shows "Reloaded next time" |
| Delete | confirm dialog, then remove and compact slots |

### 2.4 Add card and ghost slots

- The **first** empty slot is the `Add Service` card: dashed border, centred `＋` in a 44dp circle
  (`surfaceHigh`), title "Add Service" 15/600, subtitle "Tap to configure" 11 `textSecondary`.
- Every other empty slot is a ghost: `surface` at 40% opacity, no border, no content.
- With 10 services configured, the Add card disappears — the grid is full, which is the intended
  ceiling.

### 2.5 Empty state (0 services)

Replaces the grid, centred:

```
              ┌───────────────┐
              │      ＋       │
              └───────────────┘
           Add your first service

   Use your Tailscale address, for example
            100.114.10.5:3000

              [ Add Service ]
```

Primary button `#6C5CE7`, and a secondary text button "Import from JSON" for restoring an export.

### 2.6 Manual refresh

**Tapping the banner** re-runs every probe and re-reads the VPN state. That is the whole refresh
story.

An earlier draft also called for pull-to-refresh and it was dropped deliberately: the grid is sized
to fill the available height exactly and never scrolls — that is the entire point of §2 — so there is
no overscroll gesture to hang a `RefreshIndicator` on. Faking one by making the page artificially
scrollable would trade a real guarantee (ten slots, always in the same place) for a gesture that
duplicates a control already sitting at the top of the screen.

---

## 3. Screen 2 — Service View

A slim toolbar over the page. No tab strip and no address bar.

```
┌──────────────────────────────────────────────┐
│  ←    →      DSH              ↻           ⋮  │  ← toolbar, 52dp
│          100.114.169.45:3080      ▔▔▔▔▔▔▔▔▔▔ │  ← 2px progress line on its bottom edge
├──────────────────────────────────────────────┤
│                                              │
│                                              │
│                 W E B V I E W                │  ← the page, edge to edge
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

### 3.1 Toolbar

A fixed 52dp row on a `surface` background with a 1px `border` bottom edge, sitting below the
status-bar inset.

| Slot | Width | Behaviour |
|---|---|---|
| Back | 44dp | Back in page history. When there is no history the glyph becomes `✕` and it returns to the grid instead — the icon tells you which of the two it is about to do. |
| Forward | 44dp | Forward in history. Rendered `textDisabled` and non-tappable when there is nowhere to go. |
| Title | flex | Service name (15/600) over its address (10.5 mono, `textSecondary`), centred, ellipsised. |
| Reload | 44dp | Reloads the page. The escape hatch for a wedged SPA, and for when a Tailscale route has only just come up. |
| Overflow | 44dp | Menu: Open in browser, Copy address, Service settings, Close session. |

Every control is a 44dp-wide, full-height target.

**One implementation rule that matters.** Nothing that changes during navigation is passed into the
toolbar as a plain value. History availability and loading state arrive as `ValueListenable`s and are
consumed *inside* `ServiceToolbar`, so a page load rebuilds the toolbar alone and never the
`WebViewWidget` subtree. Passing `bool` values down would rebuild the WebView on every progress
tick, which is exactly what the keep-alive design is trying to avoid.

### 3.2 Progress line

2px, `primary`, pinned to the **bottom edge of the toolbar** — where a browser puts it — with its
width tracking `onProgress`. It fades out over 250 ms once loading finishes, so it costs no repaint
while idle. On a same-document navigation (`pushState`) progress never leaves 0 and the line simply
does not appear. Correct behaviour, not a bug.

### 3.3 Floating back pill — off by default

A second back control at the bottom of the page, for one-handed reach. 44dp, `surfaceHigh` at 72%
with a 12px blur, fading to 40% after 2.5 s idle; tapping it restores full opacity and goes back.

It is **off by default now** that the toolbar carries a back button — two of them is clutter — but
the switch remains in Settings under Browsing for anyone who prefers the bottom of the screen.

The original spec said "any touch anywhere restores full opacity", which would need a `Listener`
wrapped around the whole stack. That was dropped: a gesture observer layered over an Android platform
view is exactly the kind of thing that silently breaks WebView scrolling.

### 3.4 Error view (main-frame load failure)

```
              ┌───────────────┐
              │      🤖       │   ← service icon, 50% opacity
              └───────────────┘

              Omaipai
        100.114.10.5:3000              ← mono, textSecondary

        Connection refused              ← error, 15/600
   The service did not accept the
   connection on port 3000.

   If Tailscale is off, turn it on,
        then tap Retry.

        [ Retry ]   [ Open in browser ]   ← primary + outlined
```

Shown in place of the page, opaque so it fully covers whatever the WebView last painted. The toolbar
stays above it, so Reload is available even when the page never loaded.

Error strings are mapped from the failure: `Connection refused`, `Connection timed out`,
`No route to host`, `Host not found`, `TLS handshake failed`, `Cleartext HTTP is blocked`,
`Page crashed`. Each gets a one-line explanation written for a human, not a stack trace.

### 3.5 What deliberately is not here

- No tab strip.
- No address bar. The address is set once on the card; nothing on this screen edits it.
- No home button, no share sheet, no download manager, no find-in-page.

## 4. Screen 3 — Edit Service

Doubles as Add Service. Reached by tapping an unconfigured card, the Add card, or `⋮ → Edit`.
Opened as a pushed route, full-screen, `bg`, scrollable.

```
┌──────────────────────────────────────────────┐
│  ←     Edit Service                       🗑 │  ← 52dp bar, delete only when editing
│                                              │
│                 ┌─────────┐                  │
│                 │   🤖    │                  │  ← 84×84 tile, radius 22, accent@14%
│                 └─────────┘                  │
│              ┌──────────────┐                │
│              │ 📷 Change Icon│               │  ← pill, surfaceHigh
│              └──────────────┘                │
│                                              │
│  Name                                        │  ← 13/500 textSecondary
│  ┌────────────────────────────────────────┐  │
│  │ Omaipai                                │  │  ← 52dp, surface, radius 14
│  └────────────────────────────────────────┘  │
│                                              │
│  URL                                         │
│  ┌────────────────────────────────────────┐  │
│  │ http://100.114.10.5:3000               │  │  ← mono, 16sp
│  └────────────────────────────────────────┘  │
│  Tailscale address. Scheme optional —        │  ← helper, 12, textSecondary
│  we'll add http://                           │
│                                              │
│  Pin to top of grid                     ⬤━━ │  ← repurposed toggle
│                                              │
│  Check connection                       ━━⬤ │
│                                              │
│  Test Connection                             │
│  ┌────────────────────────────────────────┐  │
│  │ ● Reachable                            │  │  ← state colour
│  │ Response time: 82 ms                   │  │  ← 12, textSecondary
│  │ ┌────────┐                             │  │
│  │ │  Test  │                             │  │  ← outlined pill, right
│  │ └────────┘                             │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Desktop mode                           ━━⬤ │  ← optional, default off
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │              Save                      │  │  ← primary, 52dp, radius 14
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### 4.1 Icon block

- 84 × 84 tile, radius 22, accent at 14% background, glyph at accent colour, 40px.
- `Change Icon` pill: `surfaceHigh`, camera glyph + label, 36dp tall.
- Opens a bottom sheet with three tabs: **Icons** (a curated grid of ~64 Material glyphs),
  **Letters** (monogram — first letter of the name on a coloured tile), **Colour** (12 accent
  swatches). All local. No icon is ever fetched from the network in v1.
- The tile updates live as the user picks — no OK button.

### 4.2 Name field

Standard `DarkField`. Autofocus when the screen was opened via `Add Service`. Max 32 characters.
Empty is invalid.

### 4.3 URL field

- Monospace, `keyboardType: TextInputType.url`, `autocorrect: false`,
  `textInputAction: TextInputAction.done`.
- Placeholder: `100.114.10.5:3000`.
- **Live validation on every keystroke** (debounced 300 ms), rendered under the field:

| Input | Under-field line |
|---|---|
| empty | `Enter a host, e.g. 100.114.10.5:3000` (`textSecondary`) |
| `100.114.10.5:3000` | ✓ `Will open http://100.114.10.5:3000` (`success`) |
| `100.114.10.5` | ✓ `Will open http://100.114.10.5` (`success`) |
| `example.com` | ✓ `Will open https://example.com` (`success`) |
| `ftp://x` | ⚠ `Only http and https are supported` (`danger`) |
| `100.114.10.5:99999` | ⚠ `Port must be 1–65535` (`danger`) |
| contains a space | ⚠ `Addresses can't contain spaces` (`danger`) |

Showing the *normalised* result before saving is the key affordance — the user typed
`100.114.10.5:3000` and sees exactly what will be opened. This is the whole reason normalisation is a
tested pure function rather than inline string munging.

### 4.4 Toggles

Custom switches, track `surfaceHigh` / `primary` when on, 48dp row height, label left, switch right,
1px `border` divider between them.

| Toggle | Default | Meaning |
|---|---|---|
| Pin to top of grid | off (on for the first three) | moves the service to the earliest slot, pushing others down |
| Check connection | on | include in reachability probing |
| Desktop mode | off | send a desktop User-Agent for this service |

### 4.5 Test Connection tile

`surface`, radius 16, 16dp padding. A row: status on the left, `Test` outlined pill on the right.

| State | Left side |
|---|---|
| idle | `○ Not tested` / `Tap Test to check reachability` |
| testing | `◌ Testing…` + spinner / `Connecting to 100.114.10.5:3000` |
| online | `● Reachable` (`success`) / `Response time: 82 ms` |
| online + HTTP | `● Reachable` / `Response time: 82 ms · HTTP 200` |
| auth | `● Reachable` (`success`) / `HTTP 401 — the service is up but wants credentials` |
| offline | `○ Unreachable` (`danger`) / `Connection refused · port 3000` |

`Test` runs the **unsaved** URL, so a typo is caught before saving. Tapping the tile when a result
exists expands a detail block: resolved origin, TCP connect time, HTTP status, timestamp, and the
raw error if any.

### 4.6 Save / Delete

- `Save` is disabled (`primary` at 30%, no ripple) until name is non-empty **and** the URL validates.
- Tapping Save normalises, persists, and — if the origin changed — **evicts that service's live
  session** so the next open loads the new address (see risk register).
- On Save: pop, then the home grid animates the card into place (fade + 200 ms slide).
- `🗑` in the top bar, `danger`, only when editing. Confirm dialog: "Remove Omaipai?" /
  "This only removes the card. The service itself is untouched." / `Cancel` · `Remove`.
- Back with unsaved changes → "Discard changes?" / `Keep editing` · `Discard`.

---

## 5. Screen 4 — Settings

Reached from the gear on Home. Grouped list, `surface` sections with a `section_header` above each.
Simple and short — this is a launcher, not a control panel.

```
  ←   Settings

  APPEARANCE
  ┌────────────────────────────────────────┐
  │ Theme                          Dark  › │
  └────────────────────────────────────────┘

  PERFORMANCE
  ┌────────────────────────────────────────┐
  │ Keep loaded services              3  › │  ← 1..5, LRU budget
  │ How many services stay in memory       │
  └────────────────────────────────────────┘

  CONNECTIONS
  ┌────────────────────────────────────────┐
  │ Auto-check connections            ⬤━━ │
  │ Check interval                   45s › │
  │ Only while on Home                ━━⬤ │  ← default on
  └────────────────────────────────────────┘

  BROWSING
  ┌────────────────────────────────────────┐
  │ Show floating back button         ⬤━━ │
  │ Links outside tailnet      External  › │  ← In-app / External / Block
  │ Desktop mode by default           ━━⬤ │
  └────────────────────────────────────────┘

  DATA
  ┌────────────────────────────────────────┐
  │ Export services                        │
  │ Import services                        │
  └────────────────────────────────────────┘

  ABOUT
  ┌────────────────────────────────────────┐
  │ TailDeck 0.1.0                         │
  │ No telemetry. Your addresses never      │
  │ leave this device.                      │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │           Reset all data               │  ← danger text button
  └────────────────────────────────────────┘
```

- **Keep loaded services** — the §5 capacity. Helper text explains the tradeoff in plain words:
  "More services stay instant, but use more memory."
- **Check interval** — 30 / 45 / 60 s.
- **Links outside tailnet** — the §10 policy. Helper: "Private services open here. Everything else
  goes to your browser."
- **Export / Import** — copies the JSON to the clipboard / reads JSON from the clipboard, with a
  preview and a confirm step on import. This is the real backup story, since cloud backup is off.
- **Reset all data** — two-step confirm, typed word not required.

---

## 6. Shared components

| Component | Used by | Notes |
|---|---|---|
| `StatusDot` | cards, banner, test tile | 8dp, four states, optional spinner variant |
| `DarkField` | edit screen | label + field + helper/error line, unified |
| `SectionHeader` | settings, edit | 13/600 uppercase, `textSecondary` |
| `DarkSwitch` | edit, settings | 48dp row, label + optional helper |
| `IconTile` | card, edit, error view | glyph + accent, three sizes |
| `ConfirmDialog` | delete, discard, reset | title / body / cancel + destructive action |
| `Toast` | test connection, session closed | bottom snackbar, `surfaceHigh`, 2 s |

---

## 7. Navigation map

```
                    ┌──────────────┐
        app start   │     Home     │◀──────────────────────┐
                    └──────┬───────┘                       │
             ┌─────────────┼──────────────┬───────────────┐│
             │             │              │               ││
     tap card│      tap Add/unconfigured  │ gear          ││
             ▼             ▼              ▼               ││
     ┌──────────────┐  ┌─────────┐  ┌──────────┐          ││
     │Service View  │  │  Edit   │  │ Settings │          ││
     │(no chrome)   │  │ Service │  └────┬─────┘          ││
     └──────┬───────┘  └────┬────┘       │                ││
            │               │            │                ││
    back:   │        save ──┘      back ─┘                ││
    history │        or back                             ││
    then ───┴─────────────────────────────────────────────┘│
     (session stays warm)                                   │
                                                            │
     Service View is NOT a pushed route — it is an overlay  │
     in the root Stack. Home is never disposed, and the     │
     service widget stays mounted while deactivated.  ──────┘
```

The last point is the architectural heart of the UI: **Home ⇄ Service View is a visibility
change, not a route push**, which is exactly what keeps the pages alive without a tab strip.
Edit and Settings *are* real pushed routes, because they own no WebView state.

---

## 8. Motion

Restrained — this is a utility, and animation that delays a page open is a bug.

| Interaction | Motion |
|---|---|
| Card press | scale to 0.97, 90 ms ease-out |
| Open service | 180 ms fade + 8dp scale-up of the web layer |
| Return to grid | 160 ms fade, no slide |
| Session evicted on return | none — the card simply shows a fresh state |
| Card appearing after add | fade + 200 ms slide-up, then settle |
| Progress line | 120 ms linear width, 250 ms fade-out at completion |
| Back pill fade | 400 ms opacity to 32% after 2.5 s idle |
| Bottom sheet | 220 ms ease-out slide, scrim fade |
| Toggle | 150 ms thumb slide |

No hero animations on the card → page transition. It costs a frame and buys nothing for a WebView.

---

## 9. Accessibility

- Every card exposes a semantic label: `"Omaipai, 100.114.10.5 port 3000, online, 82 milliseconds"`.
  A `GridView` of ten near-identical cards is otherwise unusable with a screen reader.
- Status is never conveyed by colour alone — the dot is always paired with text (banner copy,
  test-tile copy) or a shape change. Red/green alone fails deuteranopia.
- All touch targets ≥ 48dp, including the `⋮` (visually 24px inside a 48dp box) and the back pill (44dp
  visual, 48dp hit area via `padding`).
- Dynamic type: card names and banner text scale; the two fixed-height rows that would break
  (banner 52dp, card name row) use `minHeight` rather than a hard height.
- Focus order on the grid is row-major, matching visual order.
- The Edit URL field is reachable by keyboard alone; `Save` is the last stop.
- Contrast: `textSecondary #8B95A5` on `surface #151A21` is ~7.4:1; `success #22C55E` on `surface`
  is ~6.9:1 — both clear AA for body text.

---

## 10. Copy deck

Every user-facing string, so tone stays consistent: plain, calm, second person, no exclamation
marks, no "Oops".

| Context | String |
|---|---|
| App tagline | Your private services, anywhere |
| Banner — connected | Tailscale Connected |
| Banner — checking | Checking connections… |
| Banner — VPN off | Tailscale appears off |
| Banner — VPN off hint | Turn on the VPN, then tap Retry. |
| Banner — services down | VPN up, services not responding |
| Banner — services down hint | Is the service still running on your PC? |
| Banner — checks disabled | Connection checks are off |
| Card — unconfigured | Tap to configure |
| Add card | Add Service |
| Empty state title | Add your first service |
| Empty state hint | Use your Tailscale address, for example 100.114.10.5:3000 |
| Edit — title | Edit Service |
| Edit — title (new) | Add Service |
| Edit — URL helper | Tailscale address. Scheme optional — we'll add http:// |
| Edit — URL valid | Will open http://100.114.10.5:3000 |
| Edit — URL scheme error | Only http and https are supported |
| Edit — URL port error | Port must be 1–65535 |
| Edit — URL space error | Addresses can't contain spaces |
| Test — idle | Not tested |
| Test — idle hint | Tap Test to check reachability |
| Test — running | Testing… |
| Test — online | Reachable |
| Test — online detail | Response time: 82 ms |
| Test — auth | HTTP 401 — the service is up but wants credentials |
| Test — offline | Unreachable |
| Session — closed | Session closed. It will reload next time. |
| Error — refused | Connection refused |
| Error — refused detail | The service did not accept the connection on port 3000. |
| Error — timeout | Connection timed out |
| Error — timeout detail | No response in 15 seconds. The host may be asleep. |
| Error — no route | No route to host |
| Error — no route detail | Tailscale may not be connected on this device. |
| Error — crash | Page crashed |
| Error — crash detail | The page ran out of memory. Retry reloads it. |
| Dialog — delete | Remove Omaipai? |
| Dialog — delete body | This only removes the card. The service itself is untouched. |
| Dialog — discard | Discard changes? |
| Settings — privacy | No telemetry. Your addresses never leave this device. |
| Settings — keep loaded helper | More services stay instant, but use more memory. |

---

## 11. Responsive rules

| Condition | Behaviour |
|---|---|
| Portrait phone (default) | 2 columns × 5 rows, as specified |
| Landscape phone | 3 columns × 4 rows (12 slots, 10 usable); WebView unaffected |
| Tablet / wide (≥ 600dp) | 4 columns; cards get a max width of 220dp and centre |
| Small height (< 640dp) | reduce grid gap to 10 and card padding to 12 before shrinking cards |
| Text scale ≥ 1.3 | card address line drops to a second elided line; name still single-line |
| Gesture nav vs 3-button nav | pill offset uses `viewPadding.bottom`, so both clear it |

v1 ships portrait-locked (see ARCHITECTURE §9.4); the table records the intended behaviour so the
grid is written against a breakpoint from the start rather than hard-coded to two columns.
