package dev.taildeck.taildeck

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.http.SslError
import android.os.Message
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/**
 * The only native code in the app.
 *
 *  - `isVpnActive`: is a VPN transport up right now? Combined with the
 *    reachability probes this distinguishes "your services are down" from
 *    "you forgot to turn Tailscale on", which is by far the most likely
 *    failure. TailDeck never starts or configures the tunnel itself.
 *
 *  - `openExternal`: hand a non-tailnet URL to the system browser, so private
 *    services stay in the app and the public web stays in Brave.
 *
 *  - `guardRenderProcess`: keeps the app alive when a WebView renderer is
 *    killed. See the note on [RenderGuardClient].
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "dev.taildeck.app/platform"
    }

    private var channel: MethodChannel? = null
    private var engine: FlutterEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = flutterEngine

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isVpnActive" -> result.success(isVpnActive())
                "openExternal" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        result.success(openExternal(url))
                    }
                }
                "guardRenderProcess" -> {
                    val identifier = call.argument<Number>("identifier")?.toLong()
                    result.success(identifier != null && guardRenderProcess(identifier))
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Scans every network rather than only the active one: Tailscale's VPN is
     * not always the default route, so `activeNetwork` alone would report false
     * negatives.
     */
    private fun isVpnActive(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        for (network in manager.allNetworks) {
            val capabilities = manager.getNetworkCapabilities(network) ?: continue
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return true
        }
        return false
    }

    private fun openExternal(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (error: Exception) {
            // No browser installed, or the scheme has no handler.
            false
        }
    }

    /**
     * Installs a [RenderGuardClient] around the WebView's existing client.
     *
     * `webview_flutter` does not implement `onRenderProcessGone`, and Android's
     * default is to **kill the whole application** when a renderer dies. That
     * happens under ordinary memory pressure — a heavy dashboard or chat SPA on
     * a busy phone is enough — so without this the launcher can vanish while the
     * user is looking at it.
     */
    private fun guardRenderProcess(identifier: Long): Boolean {
        val flutterEngine = engine ?: return false
        @Suppress("DEPRECATION")
        val webView = WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, identifier)
            ?: return false

        // Re-registering would stack wrappers.
        if (webView.webViewClient is RenderGuardClient) return true

        webView.webViewClient = RenderGuardClient(webView.webViewClient, identifier)
        return true
    }

    /**
     * Forwards every callback the `webview_flutter` client implements, and
     * claims ownership of renderer death so Android does not tear down the app.
     *
     * **Maintenance note.** The forwarded list mirrors
     * `WebViewClientProxyApi.WebViewClientImpl` in `webview_flutter_android`
     * 4.14.1. A method that plugin starts overriding later, and that is not
     * forwarded here, would silently stop reaching Dart. The plugin's client is
     * reachable only through `WebView.getWebViewClient()`, which is why this is
     * a hand-written delegate rather than a subclass.
     */
    private inner class RenderGuardClient(
        private val delegate: WebViewClient,
        private val identifier: Long,
    ) : WebViewClient() {

        override fun onRenderProcessGone(
            view: WebView,
            detail: RenderProcessGoneDetail,
        ): Boolean {
            // Tell Dart which session died so it can drop the dead WebView and
            // say so, rather than leaving a frozen page on screen.
            channel?.invokeMethod("renderProcessGone", identifier)
            return true
        }

        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
            delegate.onPageStarted(view, url, favicon)
        }

        override fun onPageFinished(view: WebView?, url: String?) {
            delegate.onPageFinished(view, url)
        }

        override fun shouldOverrideUrlLoading(
            view: WebView?,
            request: WebResourceRequest?,
        ): Boolean = delegate.shouldOverrideUrlLoading(view, request)

        override fun onReceivedError(
            view: WebView?,
            request: WebResourceRequest?,
            error: WebResourceError?,
        ) {
            delegate.onReceivedError(view, request, error)
        }

        override fun onReceivedHttpError(
            view: WebView?,
            request: WebResourceRequest?,
            errorResponse: WebResourceResponse?,
        ) {
            delegate.onReceivedHttpError(view, request, errorResponse)
        }

        override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
            delegate.doUpdateVisitedHistory(view, url, isReload)
        }

        override fun onReceivedHttpAuthRequest(
            view: WebView?,
            handler: HttpAuthHandler?,
            host: String?,
            realm: String?,
        ) {
            delegate.onReceivedHttpAuthRequest(view, handler, host, realm)
        }

        override fun onFormResubmission(view: WebView?, dontResend: Message?, resend: Message?) {
            delegate.onFormResubmission(view, dontResend, resend)
        }

        override fun onLoadResource(view: WebView?, url: String?) {
            delegate.onLoadResource(view, url)
        }

        override fun onPageCommitVisible(view: WebView?, url: String?) {
            delegate.onPageCommitVisible(view, url)
        }

        override fun onReceivedClientCertRequest(view: WebView?, request: ClientCertRequest?) {
            delegate.onReceivedClientCertRequest(view, request)
        }

        override fun onReceivedLoginRequest(
            view: WebView?,
            realm: String?,
            account: String?,
            args: String?,
        ) {
            delegate.onReceivedLoginRequest(view, realm, account, args)
        }

        override fun onReceivedSslError(
            view: WebView?,
            handler: SslErrorHandler?,
            error: SslError?,
        ) {
            delegate.onReceivedSslError(view, handler, error)
        }

        override fun onScaleChanged(view: WebView?, oldScale: Float, newScale: Float) {
            delegate.onScaleChanged(view, oldScale, newScale)
        }

        @Suppress("DEPRECATION")
        override fun onUnhandledKeyEvent(view: WebView?, event: KeyEvent?) {
            delegate.onUnhandledKeyEvent(view, event)
        }
    }
}
