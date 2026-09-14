# taildeck (app)

The Flutter application. See [`../README.md`](../README.md) for what TailDeck is and how to build and
install it, and [`../docs/`](../docs) for the architecture and UI specification.

## Quick commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

## A map of `lib/`

| Path | Responsibility |
|---|---|
| `main.dart` | loads `SharedPreferences` before `runApp`, locks portrait, sets the dark system chrome |
| `app.dart` | `MaterialApp`, and `RootShell` — the single back-navigation contract |
| `core/url_utils.dart` | turns `100.114.10.5:3000` into a loadable URL. Pure, table-tested |
| `data/models/` | `ServiceItem`, `AppSettings`, `IconRef`, `ProbeStatus` |
| `data/repositories/` | load/save, schema-versioned, never throws on corrupt data |
| `domain/probe/` | two-phase reachability probe (TCP connect, then HTTP status) |
| `state/session_lru.dart` | **the eviction policy.** No Flutter imports, so it is unit tested |
| `state/web_session_registry.dart` | owns the live WebViews; delegates ordering to `SessionLru` |
| `state/providers.dart` | Riverpod wiring, the probe scheduler, the banner derivation |
| `platform/platform_bridge.dart` | the one MethodChannel (VPN state, open-in-browser) |
| `ui/web/web_layer.dart` | the `IndexedStack` that keeps pages alive with no tab strip |

## Two things worth knowing before editing

**Never push a route to show a service.** The service view is an overlay in `app.dart`'s `Stack`, not
a route. Pushing it would dispose the `WebViewWidget` and lose the page. See `ui/web/web_layer.dart`.

**`state/providers.dart` must not rebuild the web layer.** Cards watch only their own slice of the
probe map via `ref.watch(probeProvider.select(...))`. Anything that makes `WebLayer` rebuild on a
probe tick will fight the keep-alive design.
