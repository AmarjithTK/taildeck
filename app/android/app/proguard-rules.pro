# R8 keep rules for TailDeck.
#
# Only relevant once `isMinifyEnabled` is switched on (see build.gradle.kts,
# milestone M5). Kept in the repo now so enabling shrinking is a one-line change.
#
# The Flutter engine and each plugin ship their own consumer rules, so this file
# only covers the one thing R8 cannot infer: methods reachable only from
# JavaScript through the WebView bridge.

# Any method annotated as a JavaScript interface is called reflectively.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep WebView subclass names: R8 renaming a WebView subclass has historically
# broken the platform-view plumbing.
-keep class * extends android.webkit.WebView { *; }
