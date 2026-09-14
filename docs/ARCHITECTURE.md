# TailDeck — Architecture

## Contents

1. [Scope and assumptions](#1-scope-and-assumptions)
2. [System context](#2-system-context)
3. [Layering and file tree](#3-layering-and-file-tree)
4. [Data model and persistence](#4-data-model-and-persistence)
5. [The WebView keep-alive pool](#5-the-webview-keep-alive-pool-the-core-problem)
6. [Back-navigation contract](#6-back-navigation-contract)
7. [URL normalisation](#7-url-normalisation)
8. [Reachability probing](#8-reachability-probing)
9. [Android platform requirements](#9-android-platform-requirements)
10. [Security posture](#10-security-posture)
11. [Performance rules](#11-performance-rules)
12. [Testing strategy](#12-testing-strategy)
13. [Build path and environment blocker](#13-build-path-and-environment-blocker)
14. [Milestones and acceptance criteria](#14-milestones-and-acceptance-criteria)
15. [Risk register](#15-risk-register)
16. [Explicit non-goals](#16-explicit-non-goals)

---

## 1. Scope and assumptions

**What it is.** A single-user Android launcher for services reachable over a Tailscale tailnet.
Fixed 10-slot grid, fullscreen WebView per service, local-only configuration.

**Assumptions**

| # | Assumption | Consequence if wrong |
|---|---|---|
| A1 | Tailscale runs as a separate Android app and owns the VPN tunnel | TailDeck would need `VpnService`, a much bigger project |
| A2 | Services are reached as `http://100.64.0.0/10:port` (CGNAT range Tailscale uses) | Allowlist logic in §10 needs adjusting |
| A3 | At most 10 services; a 5-row x 2-column grid always fits without scrolling | Grid becomes scrollable, card size shrinks |
| A4 | Single user, no accounts, no cloud sync | Would need auth + a backend |
| A5 | Android 8.0+ (API 26) — matches Tailscale's own floor | Lower minSdk unlocks more devices |
| A6 | The device is a phone in portrait; landscape is a bonus | Grid ratio per orientation needs a breakpoint |

**Non-negotiable behaviours**

- B1: Tapping a card never creates a browser tab anywhere.
- B2: Re-entering a recently-used service restores its page state rather than reloading.
- B3: The service view shows nothing but the page (plus a 2px progress line and a fading back pill).
- B4: No address is compiled into the binary; every address is user-editable and stored locally.
- B5: The app never exposes a port or proxies a service to the public internet.

---

## 2. System context

```
┌──────────────────────────── Android phone ────────────────────────────┐
│                                                                       │
│   ┌──────────────┐        ┌───────────────────────────────────────┐   │
│   │  Tailscale   │        │              TailDeck                 │   │
│   │  app (VPN)   │        │                                       │   │
│   │              │        │  Home grid  ──tap──▶  WebView session  │   │
│   │  owns tun0 / │◀───────│  (10 cards)           (fullscreen)     │   │
│   │  tailscale0  │  plain │       │                     │         │   │
│   └──────┬───────┘  socket │       │ probe               │ HTTP    │   │
│          │                │       ▼                     ▼         │   │
│          │                │  Socket.connect        WebView engine │   │
│          │                └───────────┬─────────────────┬─────────┘   │
└──────────┼────────────────────────────┼─────────────────┼─────────────┘
           │  encrypted WireGuard tunnel│                 │
           ▼                            ▼                 ▼
     ═══════════════════════════════════════════════════════════
                        tailnet 100.64.0.0/10
     ═══════════════════════════════════════════════════════════
           │                            │                 │
           ▼                            ▼                 ▼
   ┌───────────────┐          ┌──────────────────┐  ┌────────────┐
   │ Desktop PC    │          │ :3000 Omaipai    │  │ :8080 ...  │
   │ tailscaled    │          │ :8080 Dipsy      │  │ :8123 etc. │
   └───────────────┘          └──────────────────┘  └────────────┘
```

TailDeck only ever originates outbound connections. There is no listener, no server, no inbound
surface.

---

## 3. Layering and file tree

Four layers, dependencies pointing inward. Nothing in `domain/` or `data/` imports Flutter widgets.

```
lib/
├── main.dart                       # runApp + provider scope + portrait lock
├── app.dart                        # MaterialApp, theme, root PopScope, WebLayer host
│
├── core/
│   ├── constants.dart              # timeouts, grid dims, defaults
│   ├── url_utils.dart              # normalise / parse / validate / display-host
│   └── result.dart                 # sealed Result<T> for probe + IO
│
├── data/
│   ├── models/
│   │   ├── service_item.dart       # immutable, copyWith, toJson/fromJson
│   │   ├── app_settings.dart
│   │   ├── icon_ref.dart           # material | monogram | emoji
│   │   └── probe_status.dart       # enum + latency + http code + checkedAt
│   ├── sources/
│   │   ├── service_local_source.dart    # SharedPreferences, schema-versioned JSON
│   │   └── settings_local_source.dart
│   └── repositories/
│       ├── service_repository.dart      # CRUD, reorder, pin, seed/migrate
│       └── settings_repository.dart
│
├── domain/
│   ├── probe/
│   │   ├── reachability_probe.dart      # TCP then optional HTTP
│   │   └── probe_scheduler.dart         # concurrency cap, triggers, pause rules
│   └── vpn/
│       └── vpn_state.dart               # MethodChannel -> is a VPN transport active?
│
├── state/
│   ├── providers.dart                   # riverpod: services, settings, probe map
│   ├── session_lru.dart                 # pure LRU policy — no Flutter, unit tested
│   └── web_session_registry.dart        # owns live WebViews; order delegated to SessionLru
│
├── ui/
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── widgets/
│   │       ├── tailscale_banner.dart
│   │       ├── service_card.dart
│   │       ├── add_service_card.dart
│   │       └── service_overflow_sheet.dart
│   ├── web/
│   │   ├── web_layer.dart               # IndexedStack of live sessions
│   │   ├── service_web_view.dart        # toolbar + one session's WebViewWidget
│   │   └── widgets/
│   │       ├── service_toolbar.dart     # back / forward / title / reload / overflow
│   │       ├── web_progress_line.dart
│   │       ├── floating_back_pill.dart
│   │       └── web_error_view.dart
│   ├── edit/
│   │   ├── edit_service_screen.dart
│   │   └── widgets/
│   │       ├── icon_picker.dart
│   │       └── test_connection_tile.dart
│   ├── settings/settings_screen.dart
│   └── common/
│       ├── status_dot.dart
│       ├── dark_field.dart
│       └── section_header.dart
│
├── theme/
│   └── app_theme.dart               # colour tokens, text styles, radii
│
└── platform/
    └── android_bridge.dart          # MethodChannel wrappers (VPN state)
```

**Dependencies** (`pubspec.yaml`)

| Package | Why | Notes |
|---|---|---|
| `flutter_riverpod` | state, no `BuildContext` needed inside the session registry | pure Dart |
| `webview_flutter` | official WebView | v4 splits controller from widget — required for the pool design |
| `webview_flutter_android` | Android impl, `onCreateWindow` hook | direct dep so we can tune it |
| `shared_preferences` | persistence | only native dep; JSON blob, no codegen |
| `uuid` | stable service ids | |
| `flutter_launcher_icons` (dev) | app icon | build-time only |

Deliberately **not** used: Hive / Isar / drift (codegen overhead for ≤10 rows), Firebase (no
telemetry), `flutter_inappwebview` (only needed if the §5 fallback is required).

---

## 4. Data model and persistence

### 4.1 `ServiceItem`

```dart
class ServiceItem {
  final String id;            // uuid v4, stable across edits
  final String name;          // "Omaipai"
  final String url;           // NORMALISED: "http://100.114.10.5:3000"
  final IconRef icon;         // glyph + accent colour
  final int sortOrder;        // grid position
  final bool pinned;          // float to top of grid
  final bool probeEnabled;    // participate in reachability probes
  final bool desktopMode;     // send a desktop User-Agent
  final DateTime createdAt;
}
```

`url` is stored already normalised (§7) so every consumer — WebView, probe, card subtitle — reads
the same canonical value. The raw input is not retained; the edit screen re-displays a shortened
form.

### 4.2 Storage

One `SharedPreferences` key per collection, holding a schema-versioned JSON string:

- `taildeck.services.v1`
- `taildeck.settings.v1`

```json
{
  "schema": 1,
  "items": [
    {
      "id": "0f2c9a7e-6b31-4d2a-9f0e-2c7b5a1d8e44",
      "name": "Omaipai",
      "url": "http://100.114.10.5:3000",
      "iconKind": "material",
      "iconValue": "smart_toy",
      "accent": "#22C55E",
      "sortOrder": 0,
      "pinned": true,
      "probeEnabled": true,
      "desktopMode": false,
      "createdAt": "2026-05-16T10:00:00.000Z"
    }
  ]
}
```

Settings:

```json
{
  "schema": 1,
  "sessionCapacity": 3,
  "autoProbe": true,
  "probeIntervalSec": 45,
  "onlyProbeOnHome": true,
  "showFloatingBack": true,
  "externalLinkPolicy": "external",
  "desktopModeDefault": false
}
```

**Why not a database.** Ten immutable-ish records read once at startup. A DB adds codegen, a native
dep and a migration story for no benefit. If usage ever exceeds ~50 records or needs history, move
to `drift` — the repository interface is the seam that makes that a one-file change.

**Migration.** `ServiceLocalSource.read()` switches on `schema`. Unknown-higher schema is handled
by reading what it can and writing a backup key `taildeck.services.backup.<ts>` before any write.

**First run.** Nothing is seeded. The grid shows its empty state — "Add your first service", the
`100.114.10.5:3000` hint, and one button. Ten placeholder cards naming services you do not have
would be worse than an honest blank slate, and pre-filled addresses would silently point at nothing.

---

## 5. The WebView keep-alive pool (the core problem)

### 5.1 The requirement

No tab strip. So there is no persistent UI to host the pages — yet B2 says state must survive
leaving and re-entering a service. That means the WebView **widgets** must stay mounted somewhere
even when not visible.

### 5.2 Chosen design — `IndexedStack`, LRU-capped

```
app.dart
└── Stack
    ├── HomeScreen            (always mounted; grid visible when nothing is active)
    └── WebLayer              (rebuilds ONLY when the session list changes)
        └── IndexedStack(index: registry.activeIndex)
            ├── 0  SizedBox.expand()          <- sentinel: "the grid is showing"
            ├── 1  ServiceWebView(sessionA)
            ├── 2  ServiceWebView(sessionB)
            └── 3  ServiceWebView(sessionC)
```

`IndexedStack` keeps every child in the widget tree — so its `State`, its controller and its native
WebView all survive — while painting and hit-testing only the selected index. That is precisely
"loaded but not shown".

The sentinel at index 0 is what makes "nothing is showing" expressible: an `IndexedStack` must paint
one child, so a transparent box stands in for the grid. Because `RenderIndexedStack` only hit-tests
the selected child, the grid underneath still receives every touch — no invisible WebView can steal
a tap.

Two consequences worth stating, because they are load-bearing rather than incidental:

- Children are still **laid out** while hidden, not merely retained. That keeps each WebView's
  surface correctly sized so it has nothing to re-layout when it comes back.
- `HomeScreen` being `const` means the periodic rebuild of `RootShell` (which watches the registry
  for `PopScope`) reuses the same widget instance, so the grid is not rebuilt on every card tap.

`Offstage` inside a `Stack` is the equivalent alternative and was the original plan; `IndexedStack`
was chosen because it is the widget Flutter provides specifically for switching between kept-alive
children, with well-defined paint and hit-test ordering. `web_layer.dart` is the only file that would
change either way.

```dart
class WebSession {
  final String serviceId;
  final WebViewController controller;
  final ValueNotifier<double> progress;   // 0..1 for the top line
  final ValueNotifier<ProbeStatus?> error; // main-frame failure, if any
  int lastUsedAt;                          // monotonic counter for LRU
}

class WebSessionRegistry {
  final _sessions = <String, WebSession>{};  // insertion order == LRU order
  int capacity = 3;                          // from settings

  WebSession acquire(ServiceItem s);  // create-or-touch, then evict while over capacity
  void touch(String id);
  void evict(String id);              // dispose controller, drop widget
  void setCapacity(int n);
  List<WebSession> get live;          // drives WebLayer children, LRU order
}
```

Rules the registry enforces:

1. **Never evict the active session**, even if over capacity — evict the next-oldest instead.
2. Capacity is live-editable (Settings 1–5). Lowering it evicts immediately, oldest first.
3. Eviction disposes the `WebViewController` and removes the widget from the `Stack`, so the WebView
   is actually freed rather than leaked.
4. Tapping an evicted card recreates a session and loads the URL fresh — the honest cost of LRU.
5. `Close session` in the card overflow menu is a manual evict, for when a heavy page (ChatGPT) is
   hogging memory.

### 5.3 Why not "keep only the controller alive"

`webview_flutter` v4 splits `WebViewController` from `WebViewWidget`, but the native WebView is bound
to the widget's platform view. Dropping the widget and re-attaching the controller later does not
reliably preserve page state. Keeping the widget mounted (this design) is the version that actually
holds state.

### 5.4 Fallback — `flutter_inappwebview` headless pool

If `Offstage` turns out to misbehave with Android platform views (black or blank view on resume), the
upgrade path is `flutter_inappwebview` v6, which provides a true `HeadlessInAppWebView` — a running
WebView with no widget at all — that can be attached to an `InAppWebView(webViewController: ...)`
when it needs to be shown. This is a swap of `WebSession` internals plus a `WebLayer` rewrite; the
rest of the app is unaffected because the registry is the only thing that knows about the plugin.

### 5.5 Page-level settings (per session)

| Setting | Value | Reason |
|---|---|---|
| `JavaScriptMode` | `unrestricted` | dashboards and chat UIs need it |
| DOM storage | **already on** | `AndroidWebViewController`'s constructor sets `setDomStorageEnabled(true)`; do not set it again |
| `window.open` | **already on** | same constructor sets `setJavaScriptCanOpenWindowsAutomatically(true)` and `setSupportMultipleWindows(true)` |
| `target="_blank"` | **works with no extra plumbing** | see the note below |
| `setBackgroundColor` | `#0A0E13` | no white flash between page loads |
| `setMediaPlaybackRequiresUserGesture` | `true` | no surprise audio |
| `setGeolocationEnabled` | `false` | not needed |
| User-Agent | default, or desktop string when `desktopMode` | some dashboards are better wide |
| progress | `NavigationDelegate.onProgress` → top line | |

**The `target="_blank"` finding (this replaced the original plan).** The design originally called for
`AndroidWebViewController.setOnCreateWindow`, forwarding popups into the same WebView by hand. That
method **does not exist** in the Dart API of `webview_flutter_android` 4.14.1 — it exists only on the
native side. Reading
`android/src/main/java/io/flutter/plugins/webviewflutter/WebChromeClientProxyApi.java` shows the
plugin already implements the behaviour we want:

1. `WebViewProxyApi.setWebViewClient` pushes the WebView's client into the chrome client
   (`currentWebChromeClient.setWebViewClient(webViewClient)`).
2. `SecureWebChromeClient.onCreateWindow` creates a throwaway WebView, asks the **main** view's
   `WebViewClient.shouldOverrideUrlLoading`, and when that returns false calls
   `view.loadUrl(request.getUrl())` — on the *original* WebView.

So a popup is re-loaded as a normal navigation, which means it also flows through
`NavigationDelegate.onNavigationRequest` and therefore through `_decide()`. The external-link policy
governs popups for free, and no custom native code is required. This is the single largest
simplification the implementation produced, and it removes the biggest item from §15's risk register.

Deliberately **not** setting a custom `webViewIdentifier`/data-directory suffix in v1 — see the
cookie caveat in §15.

---

## 6. Back-navigation contract

One authoritative handler at the root, so back behaves identically whether it comes from the system
button, the predictive-back gesture, or the floating pill.

```
Back pressed
│
├─ Is a route pushed (Edit / Settings)?
│    └─ yes → pop that route. If it has unsaved edits, show "Discard changes?" first.
│
├─ Is a service active?
│    ├─ controller.canGoBack() == true  → controller.goBack()   (stay in the service)
│    └─ canGoBack() == false            → activeServiceId = null (show grid, KEEP the session)
│
└─ Grid is already showing → allow the app to close.
```

Implementation: `PopScope(canPop: false, onPopInvokedWithResult: ...)` at the root, plus
`android:enableOnBackInvokedCallback="true"` in the manifest so Android 13+ predictive back routes
through it instead of killing the Activity.

Step 2's `canGoBack() == false` is the important one: it **deactivates** rather than disposes. The
session goes offstage and stays warm, which is what makes "jump to Omaipai, jump back to Dipsy,
jump back to Omaipai" feel instant.

The floating pill mirrors this exactly (tap = back-in-history-or-grid). Long-press the pill =
force straight to the grid, skipping history.

---

## 7. URL normalisation

The whole point is not having to type `http://100.` — so input handling is a first-class feature,
not a `TextField` afterthought.

```
"100.114.10.5:3000"      -> http://100.114.10.5:3000
"100.114.10.5"           -> http://100.114.10.5        (port 80 implied)
"http://100.114.10.5:3000/"  -> http://100.114.10.5:3000        (trailing slash trimmed)
"grafana.local:3000"     -> http://grafana.local:3000
"192.168.1.50:8123"      -> http://192.168.1.50:8123
"omaipai"                -> http://omaipai              (single label = MagicDNS name)
"example.com"            -> https://example.com        (public host -> TLS assumed)
"  Omaipai  "            -> trimmed, then as above
```

Algorithm:

1. Trim, collapse internal whitespace, reject empty.
2. If a scheme is present (`^[a-z][a-z0-9+.-]*://`) keep it; only `http` and `https` are accepted.
3. Otherwise decide the scheme:
   - private host → `http://` — matches `100.64.0.0/10`, `10/8`, `172.16/12`, `192.168/16`,
     `127.0.0.1`, `localhost`, `*.local`, `*.ts.net`, any bare IPv4, **and any single-label name**.
   - anything else → `https://`.
4. Default the port from the scheme when absent.
5. Keep any path/query the user typed (`http://100.114.10.5:3000/admin` stays intact), but drop a
   bare trailing slash so `host:3000/` and `host:3000` produce the same stored value.
6. Reject anything with a space in the authority; surface an inline field error rather than silently
   mangling it.

Two derived views:

- `displayHost` → `100.114.10.5:3000` (scheme, default port and trailing slash dropped) — this is
  what the card subtitle shows, matching the mockup.
- `origin` → `http://100.114.10.5:3000` — used by the probe and by the tailnet allowlist.

Implementation lives in `core/url_utils.dart` as pure functions and is covered by a table-driven
unit test with the cases above as literal expected values.

---

## 8. Reachability probing

### 8.1 Two-phase probe

**Phase 1 — TCP connect.** `Socket.connect(host, port, timeout: 1500ms)`.

This is the truest test: host up, port open, tunnel working. It is independent of HTTP semantics, so
a service returning 500 still counts as reachable. The connect duration is the **response time**
shown on the card.

**Phase 2 — HTTP request (only when phase 1 succeeded and `probeEnabled`).**

`HttpClient` GET with `connectionTimeout: 1500ms`, `idleTimeout: 2s`, read the status code, close
the response unread. Any status — 200, 302, 401 — means "Reachable". Only a socket/TLS error means
"Unreachable". The status code is surfaced on the edit screen's expanded test row.

`ProbeStatus`:

```dart
enum ProbeState { unknown, checking, online, offline }

class ProbeStatus {
  final ProbeState state;
  final int? latencyMs;     // phase-1 connect time
  final int? httpStatus;    // phase-2, null if not run
  final String? error;      // "Connection refused" / "Timed out" / ...
  final DateTime checkedAt;
}
```

### 8.2 Scheduling

| Trigger | Behaviour |
|---|---|
| App cold start | all enabled services, after first frame, staggered 120 ms apart |
| `AppLifecycleState.resumed` | all enabled, results older than 10 s |
| Pull-to-refresh on the grid | all enabled, immediate |
| Banner tap | all enabled, immediate |
| Periodic timer | every `probeIntervalSec` (default 45) — **only while Home is visible** |
| After saving an edited service | that one service only |

Rules:

- **Concurrency cap 4.** A `Pool`-style queue; ten cards must never open ten sockets at once.
- **Pause while a service is in the foreground.** The timer stops when `activeServiceId != null`, so
  probing never competes with a page load for the tunnel.
- **Never probe twice concurrently for the same service.** In-flight ids are tracked in a set.
- Per-service `probeEnabled = false` is respected everywhere; such a card shows a neutral grey dot
  and no latency.

### 8.3 The Tailscale banner

Derived from the probe map plus a VPN check, never from a guess:

```
any online                     -> ● Tailscale Connected       (green)
probes in flight, none yet     -> ◌ Checking connections...   (muted, spinner)
all enabled probes offline
   AND vpnTransportActive      -> ● VPN up, services down      (amber)  "Is the service running?"
all enabled probes offline
   AND !vpnTransportActive     -> ● Tailscale appears off      (red)    "Turn on the VPN, then retry"
```

`vpnTransportActive` comes from a ~20-line Kotlin MethodChannel that asks `ConnectivityManager` for
a network with `TRANSPORT_VPN`. It is worth the native code because it turns the single most likely
failure ("I forgot to turn Tailscale on") into a specific, actionable message instead of a generic
"unreachable". If the channel is unavailable, the banner falls back to the two-state version.

---

## 9. Android platform requirements

### 9.1 Manifest

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<application
    android:usesCleartextTraffic="true"
    android:allowBackup="false"
    android:enableOnBackInvokedCallback="true"
    android:hardwareAccelerated="true"
    android:launchMode="singleTop"
    android:windowSoftInputMode="adjustResize"
    android:configChanges="orientation|screenSize|screenLayout|keyboardHidden|smallestScreenSize|uiMode|density">

    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
    </queries>
</application>
```

Why each non-obvious line matters:

- **`usesCleartextTraffic="true"`** — your services are `http://`. Android 9+ blocks cleartext by
  default, so without this *nothing loads*. The tidier `network_security_config.xml` approach
  **cannot express this case**: its `<domain>` element takes hostnames, not CIDR ranges, so
  `100.64.0.0/10` is not expressible. Enumerating the ten IPs would break the moment you edit an
  address in-app. Given the app only talks to your tailnet, a global cleartext flag is the honest
  trade — and it is recorded in §10 as an accepted risk.
- **`allowBackup="false"`** — otherwise your tailnet addresses (a map of your private network) get
  swept into Google's cloud backup.
- **`enableOnBackInvokedCallback="true"`** — routes Android 13+ predictive back through Flutter's
  `PopScope`, so §6 actually gets to run.
- **`configChanges` list** — without it, rotation or a theme change recreates the Activity, which
  destroys every live WebView and defeats the entire keep-alive design. This is a functional
  requirement, not a nicety.
- **`windowSoftInputMode="adjustResize"`** — makes keyboards work inside WebView forms.
- **`<queries>`** — needed on API 30+ so "Open in external browser" can check for a handler.

### 9.2 Gradle

| Setting | Value | Reason |
|---|---|---|
| `minSdk` | 26 | matches Tailscale's own Android floor |
| `compileSdk` / `targetSdk` | 36 | installed in `~/Android/Sdk/platforms` |
| `applicationId` | `dev.taildeck.app` | what shows on the phone |
| `namespace` | `dev.taildeck.taildeck` | what the generated Kotlin package uses; the two may differ |
| `versionName` | `1.0.0+1` | from `pubspec.yaml` via `flutter.versionName` |
| Java/Kotlin target | 17 | see the JDK caveat in §13 |
| release build | `minifyEnabled false`, `shrinkResources false` **for now** | `proguard-rules.pro` is in place; shrink is an M5 item because an R8 misconfiguration in a WebView host fails at runtime, not at build time |

### 9.3 Edge-to-edge and insets

Android 15+ enforces edge-to-edge. The grid uses `SafeArea`; the WebView is genuinely edge-to-edge
(that is the point) but its progress line and floating pill are inset by
`MediaQuery.viewPadding` so they never sit under the status bar or gesture bar.

### 9.4 Orientation

Portrait-locked in v1 (`SystemChrome.setPreferredOrientations`). Landscape is a v2 item: the grid
would go to 3 columns and the WebView obviously benefits from the extra width.

---

## 10. Security posture

**What TailDeck does not do**

- No analytics, no crash reporting, no network calls other than to the addresses you configured.
- No accounts, no sync, no server, no listening socket, no reverse proxy.
- Does not start, stop, or configure Tailscale; does not request `VpnService`.

**What it does do**

| Concern | Decision |
|---|---|
| Addresses at rest | `SharedPreferences` JSON, app-private. Not encrypted — an unlocked device can read them. Optional app-lock (biometric/PIN) is a v2 item. |
| Cloud backup | Disabled (`allowBackup="false"`). |
| Cleartext | Allowed app-wide (§9.1) because the tailnet is the trust boundary and CIDR cannot be expressed in a network security config. |
| Links leaving the tailnet | Default policy **External**: a navigation to a host outside `100.64.0.0/10` + your configured hosts is handed to the system browser instead of loading in-app. Your private services stay in TailDeck; the public web stays in Brave. Configurable to In-app / Block. |
| WebView JS bridge | None. We never call `addJavaScriptChannel` for our own bridge, so a compromised page has no privileged surface. |
| File chooser / downloads | Not enabled in v1. Enabling downloads means files land on disk from a JS-capable context — deliberately out of scope until needed. |
| Release signing | A keystore you generate and keep. Documented in the build section; never committed. |

**Accepted risks**

- A with-tailnet-reachable page has full JS and DOM-storage access in an unrestricted WebView. This
  is inherent to "show my dashboard in an app". The `External` link policy limits how a page can
  wander off the tailnet.
- Cleartext HTTP on the tailnet is unencrypted at the application layer; WireGuard encrypts it in
  transit. Readable only by the two endpoints, both of which are yours.

---

## 11. Performance rules

These are constraints on the implementation, not suggestions — each one exists because violating it
breaks B2 (state preservation).

1. **Probe updates must never rebuild the `WebLayer` subtree.** The live WebViews live in their own
   widget that watches only `webSessionRegistry`. Cards subscribe to the probe map individually via
   a scoped consumer, so a dot changing colour on card 3 does not touch the pages on screen.
2. **The session widget list is computed once per session-list change**, not per rebuild. Keep the
   `List<Widget>` in the registry (or a memoised provider), never build it inline in a widget that
   rebuilds for unrelated reasons.
3. **`RepaintBoundary`** around each `ServiceWebView` and each grid card.
4. **The grid is not lazy.** Ten fixed slots — a plain `GridView` with
   `NeverScrollableScrollPhysics` and a fixed `childAspectRatio`, no lazy building, no recycling.
5. **No live page previews on cards.** Rendering ten thumbnails would mean ten more WebViews and
   would blow the memory budget. Cards show an icon tile, the mockup's choice.
6. **Probe concurrency 4, timeout 1.5 s.** A dead address must not stall the UI for 30 s.
7. **All persistence writes are debounced** (~300 ms) and happen off the frame callback.
8. **Memory budget**: 3 live WebViews ≈ 150–250 MB for typical dashboards; a heavy SPA can be more.
   That is why capacity is a setting and why `Close session` exists in the overflow menu.

---

## 12. Testing strategy

**Unit (no device)**

- `url_utils`: the table in §7, plus rejects (empty, spaces in authority, `ftp://`, junk ports).
- `WebSessionRegistry`: LRU order, capacity shrink evicts oldest, active session is never evicted,
  `touch` reorders, `evict` is idempotent.
- `ServiceItem` / `AppSettings` JSON round-trip, including a missing-field payload and a
  future-`schema` payload (must not throw, must not lose data).
- `ServiceRepository`: add / edit / reorder / pin / delete, slot compaction after a delete.
- `ProbeStatus` mapping from injected socket outcomes (inject a fake connector — no real sockets in
  unit tests).

**Widget**

- Grid renders 10 slots for 3 services (3 cards + 7 empty/Add cards).
- Empty state renders when there are 0 services.
- Card tap calls `registry.acquire` with the right id.
- `PopScope` handler: history available → `goBack`; history exhausted → deactivate, session still in
  `registry.live`.
- Edit screen Save is disabled until name and URL are valid; validation error shows for junk input.

**Manual, on the device** (the parts a test cannot fake)

- Tailscale on vs off → banner copy and dot colours.
- Rotate while a page is loaded → page state survives (proves §9.1 `configChanges`).
- Background the app for 10 minutes, resume → sessions still alive, or the crash-recovery path fires.
- Open four services in order → the first is evicted, the last three are warm.
- ChatGPT: send a message, leave, come back → conversation still on screen.
- A page with `target="_blank"` → loads in the same WebView, no new window.
- Keyboard in a WebView form → field is not hidden behind the keyboard.
- Kill Tailscale mid-session → probe flips to offline within one interval.
- Process death (Developer options → Don't keep activities) → app restarts cleanly with settings intact.

Gates: `flutter analyze` clean, `flutter test` green.

---

## 13. Build path and environment blocker

### 13.1 Commands

```bash
# scaffold (inside the workspace)
flutter create --org dev.taildeck --project-name taildeck --platforms=android app

# deps
flutter pub add flutter_riverpod webview_flutter webview_flutter_android \
                shared_preferences uuid
flutter pub add dev:flutter_launcher_icons

# run on a USB device
flutter run -d <device-id>

# ship
flutter build apk --release --split-per-abi
# -> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### 13.2 The blocker on this machine

The filesystem is mounted read-only outside the workspace. A Flutter Android build writes to
**five** places that are currently `ro`:

| Path | Needed for |
|---|---|
| `$FLUTTER_ROOT/bin/cache/lockfile` | the `flutter` tool cannot even start without this |
| `$FLUTTER_ROOT/bin/cache/*` | engine artifact refresh |
| `~/.pub-cache` | `pub get` downloads `shared_preferences`, `webview_flutter`, etc. |
| `~/.gradle` | Gradle distribution + AGP/Kotlin dependencies |
| `~/Android/Sdk` | licence files, possibly build-tools metadata |

Observed failures confirm it:

```
Failed to open or create the artifact cache lockfile:
  "FileSystemException: Cannot open file, path =
   '/home/starwalker/flutter/bin/cache/lockfile' (OS Error: Read-only file system, errno = 30)"
```

So the build step needs either:

1. a run with the wider **danger-full-access** sandbox mode in this session, or
2. a normal shell on the host outside DSH, or
3. a container/CI with a writable Flutter + Gradle + pub cache.

**Also required for the first Android build:** network access for the Gradle distribution and for
AGP/Kotlin artifacts (~1–2 GB on a cold cache). The design and scaffold work does not need it.

### 13.3 JDK caveat

Only JDK **26** is installed (`/usr/lib/jvm/java-26-openjdk`) and there is no system Gradle — the
project would use the Flutter-generated Gradle wrapper. Gradle's Java support lags new JDK
releases, and AGP has its own matrix, so JDK 26 plus a freshly generated wrapper is a plausible
first-build failure ("Unsupported class file major version"). Mitigation, in order:

1. Try the generated wrapper as-is.
2. If it fails, raise the wrapper's Gradle version to one that supports JDK 26.
3. Otherwise install JDK 17 or 21 and point the build at it via `org.gradle.java.home` in
   `android/gradle.properties` or `flutter config --jdk-dir`.

Worth resolving at milestone M0, before any feature work, so a toolchain problem is not mistaken for
a code problem.

---

## 14. Milestones and acceptance criteria

| # | Milestone | Contents | Done when |
|---|---|---|---|
| **M0** | Toolchain + skeleton | `flutter create`, deps, theme tokens, empty grid, Gradle/JDK sanity | debug APK installs and launches on the phone; `flutter analyze` clean |
| **M1** | Launcher | `ServiceItem`, repository, SharedPreferences persistence, home grid, add / edit / delete, starter pack | add Omaipai with `100.114.10.5:3000`, kill the app, relaunch — the card is still there |
| **M2** | WebView core | session registry, LRU 3, fullscreen WebView, top progress line, floating pill, back contract, `target="_blank"` in-place, error page | open 4 services in turn; the last 3 keep their scroll position; back from a loaded page returns to the grid and back again re-shows the same page |
| **M3** | Probing | TCP + HTTP probe, scheduler, status dots, latency, Tailscale banner, pull-to-refresh, VPN channel | with Tailscale off every card is red and the banner says so within one interval; with it on, times appear |
| **M4** | Polish | icon picker, pin/reorder, settings screen, import/export JSON, external-link policy, desktop UA, empty/error states, app icon | every screen in `UI_SPEC.md` exists and matches; export → wipe → import restores the grid |
| **M5** | Release | signing, shrink, `--split-per-abi`, on-device pass of §12's manual list | signed APK installed from scratch behaves identically to the debug build |

M2 is the risky one — it is where the keep-alive design and the Gradle/JDK toolchain both get
proven. Schedule accordingly.

---

## 15. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `Offstage` + Android platform view renders black on resume | medium | blank page | fall back to `IndexedStack`; if still broken, §5.4 `flutter_inappwebview` headless pool |
| Android kills the WebView renderer under memory pressure | medium | page dies mid-session | listen for renderer-gone / main-frame error, evict that session, show the error page with Retry |
| JDK 26 incompatible with the generated Gradle/AGP | medium | M0 blocked | §13.3 ladder; resolve first |
| Cleartext blocked on Android 9+ | high if missed | nothing loads at all | `usesCleartextTraffic="true"` (§9.1) — decided, not optional |
| Cookies shared across services (one `CookieManager`) | high | logging into A can affect B | accepted in v1 and documented; v2 uses `WebViewFeature.MULTI_PROFILE` + `ProfileStore` (Android 9+, WebView 90+) for per-service isolation |
| Editing a URL does not affect an already-warm session | certain | stale page | on save, evict that service's session if the origin changed |
| 10 cards x probe on every resume drains battery | low | battery | concurrency cap 4, 1.5 s timeout, timer only while Home is visible, per-card opt-out |
| Tailscale IP changes (DHCP or MagicDNS off) | low | cards go red | MagicDNS hostnames are supported by §7; import/export makes bulk fixing easy |
| A service returns 401 and looks "broken" | medium | confusion | the banner and card show *reachable but unauthorised* when phase 2 returns 401/403 |

---

## 16. Explicit non-goals

- Not a general browser: no bookmarks, no history, no download manager, no private mode.
- Not a Tailscale client: no `VpnService`, no device management, no ACL editing, no MagicDNS config.
- No live page thumbnails on the cards.
- No cloud sync, accounts, sharing, or telemetry.
- No public exposure, tunnel, or reverse proxy of any service.
- No port scanning or service discovery. You type the address once; that is the input method.
- No iOS, web, or desktop target in v1. The Dart layers are kept platform-agnostic so a future
  target is a UI port, not a rewrite.
