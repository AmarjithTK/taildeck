# TailDeck

A personal **Tailscale service launcher + mini-browser** for Android.

Your private services live at addresses like `http://100.114.10.5:3000`. Opening those in Brave means
a tab graveyard and retyping `100.x.y.z:port` forever. TailDeck replaces that with a fixed
**2 columns x 5 rows grid of 10 service cards**. Tap a card, the service opens full-screen in an
in-app WebView. Come back, tap another card, and the first one is still exactly where you left it.

> Status: **M0–M2 built and passing.** The app compiles, the test suite is green, and it produces an
> installable APK. What remains is M3–M5 in the architecture doc (see *Not done yet* below).

```
Flutter app  ->  Home grid (10 cards)  ->  fullscreen WebView per service  ->  Tailscale VPN  ->  your desktop
```

TailDeck does **not** manage the tunnel. You turn Tailscale on the way you already do; TailDeck is
just the pretty front door and the address book.

---

## Documents

| Document | What's in it |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, data model, persistence, the WebView keep-alive pool, reachability probing, Android manifest requirements, security posture, file tree, milestones, risk register |
| [`docs/UI_SPEC.md`](docs/UI_SPEC.md) | Screen-by-screen UI spec with wireframes, spacing, colour tokens, states, and the exact back-navigation contract |

Both are kept current with the implementation; where the code diverged from the plan, the doc says
so and explains why.

## Layout

```
app/                      Flutter project (Android only)
├── lib/
│   ├── core/             constants, URL normalisation (pure + unit tested)
│   ├── data/             models, SharedPreferences store, repositories
│   ├── domain/probe/     two-phase TCP + HTTP reachability probe
│   ├── state/            Riverpod providers, session LRU, WebView registry
│   ├── platform/         the one MethodChannel to native Android
│   ├── theme/            colour and type tokens
│   └── ui/               home grid, service view, edit, settings
├── android/              manifest, Gradle, MainActivity (VPN check + open-in-browser)
└── test/                 53 unit and widget tests
```

The launcher icon is generated, not hand-drawn: `tools/generate_icons.py` renders the
dark-navy 2×2 tile motif (the app palette) to every legacy density plus the adaptive-icon
foreground, with the background as a colour resource. Regenerate with `python3 tools/generate_icons.py`; it writes straight into `app/android/.../`res`.

## Build and install

```bash
cd app
flutter pub get
flutter analyze                 # clean
flutter test                    # 53 passing

# smaller, faster, for daily use
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`arm64-v8a` covers essentially every phone from the last several years. Drop `--split-per-abi` for a
single universal APK if you are not sure.

### Toolchain note for this machine

Only JDK 26 is installed, which the generated Gradle 9.1.0 does not support. A JDK 21 ships with the
Android SDK, so point Flutter at it once:

```bash
flutter config --jdk-dir=/home/starwalker/Android/jdk21/jdk-21.0.12+8
```

Also, the filesystem is mounted read-only outside this workspace, so a build needs a shell with write
access to `$FLUTTER_ROOT/bin/cache`, `~/.pub-cache` and `~/.gradle`.

## Decisions locked in

| Question | Decision |
|---|---|
| Chrome inside the WebView | **A slim toolbar only.** Back, forward, title, reload, overflow — no tab strip and no address bar. The floating back pill survives as an option, off by default. |
| How many services stay loaded | **3 most recent (LRU).** Switching back preserves scroll and page state; older ones reload. The active session is never evicted. |
| Back button | Back in page history first; when history is exhausted, return to the grid *without* destroying the session. |
| Address storage | Local JSON in `SharedPreferences`. **No IPs hard-coded in source.** Editable in-app. |
| Connectivity | Per-card reachability dot + latency, plus a global Tailscale banner backed by a real VPN-transport check. |
| Scope | Android only. No cloud, no accounts, no telemetry, no public proxy. |

## Verified on device

Installed with `adb` on a Redmi `23027RAD4I` (arm64-v8a, Android 15) and driven through the real
flows against a live tailnet service.

| Check | Result |
|---|---|
| Install, cold launch | clean — no Dart errors, no crash |
| Home empty state | renders as specified — [`01-empty-state.png`](docs/screenshots/01-empty-state.png) |
| Add Service → Edit | renders; the URL field validated `100.114.169.45:3080` live as **"Will open http://100.114.169.45:3080"** — the CGNAT range correctly resolved to `http://` — [`02-url-validation.png`](docs/screenshots/02-url-validation.png) |
| Malformed input | a garbled `100.114.100.114.169.45` was correctly treated as non-private and would have used `https://` |
| Save and persist | card lands in slot 1; the dashed Add card moves to slot 2 |
| Probe against a live service | online, **15 ms**, green dot; banner green "Tailscale Connected" — [`03-service-online.png`](docs/screenshots/03-service-online.png) |
| Card tap → WebView | the DeepSeek Harness SPA rendered in full, edge to edge under the toolbar — [`04-service-view.png`](docs/screenshots/04-service-view.png) |
| Toolbar on device | back/close, forward (correctly disabled with no history), title, reload and overflow all present and behaving |
| **Keep-alive pool** | `✕` to the grid, then tap the card again: the page returned in **under 2 s** where a cold load takes 12+ s — and it had **advanced while hidden**, so the WebView stayed mounted *and* kept its WebSocket alive — [`05-keepalive.png`](docs/screenshots/05-keepalive.png) |
| Back to grid | `✕` (no history) returns to the grid without dropping the session |

For the record, the tailnet in play: this machine is `proximacentauri-home-pc` at `100.114.169.45`,
the phone is `redmi-note-12` at `100.83.240.98`. The mockup's `100.114.10.5` addresses are
illustrative — your real ones differ.

## Not done yet

- **Rotation, backgrounding and `target="_blank"`** are covered by unit and widget tests but not yet
  exercised by hand on the device. The full checklist is
  [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §12.
- **M4 release:** the build signs with the debug keystore and R8 shrinking is deliberately off.
  `proguard-rules.pro` is in place; enabling it needs an on-device pass first, because an R8
  misconfiguration in a WebView host fails at runtime rather than at build time.
