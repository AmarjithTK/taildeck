import 'package:flutter/services.dart';

/// The single MethodChannel to native Android — ARCHITECTURE.md §8.3 and §10.
///
/// Two capabilities that would otherwise each cost a plugin dependency:
///   * is a VPN transport currently active (turns "unreachable" into
///     "Tailscale appears off")
///   * hand a URL to the system browser (the external-link policy)
///
/// Every call degrades gracefully: in unit tests and on any platform without
/// the channel, these throw [MissingPluginException] and callers treat that as
/// "unknown" rather than an error.
class PlatformBridge {
  const PlatformBridge();

  static const MethodChannel channel = MethodChannel('dev.taildeck.app/platform');

  /// Null when the platform cannot tell us.
  Future<bool?> isVpnActive() async {
    try {
      return await channel.invokeMethod<bool>('isVpnActive');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Arms the native renderer-death guard for a WebView.
  ///
  /// Android kills the whole process when a WebView renderer is reclaimed
  /// unless the app's `WebViewClient` claims ownership of the event. Returns
  /// false when the native side could not find the WebView, in which case the
  /// app keeps Android's default (fatal) behaviour.
  Future<bool> guardRenderProcess(int webViewIdentifier) async {
    try {
      final guarded = await channel.invokeMethod<bool>(
        'guardRenderProcess',
        <String, Object>{'identifier': webViewIdentifier},
      );
      return guarded ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Native calls back when a renderer is reclaimed, so the dead session can be
  /// dropped instead of left frozen on screen.
  static void setRenderProcessGoneHandler(
    void Function(int webViewIdentifier)? handler,
  ) {
    if (handler == null) {
      channel.setMethodCallHandler(null);
      return;
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'renderProcessGone') {
        final identifier = call.arguments;
        if (identifier is int) handler(identifier);
      }
      return null;
    });
  }

  /// True when an app took the intent. Never throws.
  Future<bool> openExternal(String url) async {
    try {
      final opened = await channel.invokeMethod<bool>('openExternal', <String, String>{
        'url': url,
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
