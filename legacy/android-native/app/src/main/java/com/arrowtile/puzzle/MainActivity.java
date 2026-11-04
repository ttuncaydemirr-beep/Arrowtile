package com.arrowtile.puzzle;

import android.annotation.SuppressLint;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;

import androidx.activity.ComponentActivity;
import androidx.activity.EdgeToEdge;
import androidx.activity.OnBackPressedCallback;
import androidx.core.graphics.Insets;
import androidx.core.view.OnApplyWindowInsetsListener;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import androidx.webkit.WebViewAssetLoader;

import java.io.ByteArrayInputStream;
import java.util.Collections;

/**
 * Tam ekran WebView kabuğu. Oyun APK içindeki assets/www/ klasöründen
 * https://appassets.androidplatform.net/ adresiyle (WebViewAssetLoader) yüklenir; file:// kullanılmaz.
 *
 * Güvenlik: JS açık; dosya ve içerik erişimi kapalı; yalnızca appassets alan adı WebView'e yüklenir,
 * mailto: ve gizlilik politikası adresi sistem uygulamasında açılır, diğer tüm dış adresler engellenir.
 */
public class MainActivity extends ComponentActivity implements AndroidBridge.Host {

    static final String START_URL = "https://" + WebViewAssetLoader.DEFAULT_DOMAIN + "/index.html";
    private static final String BACK_JS =
            "(function(){try{return window.ArrowtileApp&&window.ArrowtileApp.onBack?String(window.ArrowtileApp.onBack()):'exit'}catch(e){return 'exit'}})()";

    private final Handler main = new Handler(Looper.getMainLooper());
    private FrameLayout root;
    private WebView web;
    private WebViewAssetLoader assetLoader;
    private AdsManager ads;
    private ConsentManager consent;
    private BillingManager billing;
    private AndroidBridge bridge;
    private boolean destroyed = false;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // targetSdk 35+ uygulamalar Android 15+ cihazlarda zorunlu olarak kenardan kenara (edge-to-edge) çizilir.
        // Aynı davranışı tüm sürümlerde etkinleştirip güvenli alanı (durum/gezinme çubuğu, çentik, klavye)
        // kök görünüme dolgu olarak uyguluyoruz; böylece oyun hiçbir çubuğun altında kalmaz.
        EdgeToEdge.enable(this);
        super.onCreate(savedInstanceState);

        root = new FrameLayout(this);
        root.setBackgroundColor(getColor(R.color.app_bg));
        web = new WebView(this);
        web.setBackgroundColor(getColor(R.color.app_bg));
        root.addView(web, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);

        ViewCompat.setOnApplyWindowInsetsListener(root, new OnApplyWindowInsetsListener() {
            @Override public WindowInsetsCompat onApplyWindowInsets(View v, WindowInsetsCompat insets) {
                Insets safe = insets.getInsets(WindowInsetsCompat.Type.systemBars()
                        | WindowInsetsCompat.Type.displayCutout()
                        | WindowInsetsCompat.Type.ime());
                v.setPadding(safe.left, safe.top, safe.right, safe.bottom);
                return WindowInsetsCompat.CONSUMED;
            }
        });

        configureWebView();

        // Monetizasyon: Billing hemen; reklamlar yalnızca UMP onayı izin verince başlar.
        ads = new AdsManager(this);
        billing = new BillingManager(this, new BillingManager.Listener() {
            @Override public void onAdFreeChanged(boolean adFree) { if (bridge != null) bridge.notifyStateChanged(); }
        });
        consent = new ConsentManager(this, new ConsentManager.Listener() {
            @Override public void onCanRequestAds() { if (!destroyed) ads.initialize(); }
            @Override public void onPrivacyOptionsChanged() { if (bridge != null) bridge.notifyStateChanged(); }
        });
        bridge = new AndroidBridge(this, ads, billing, consent);
        web.addJavascriptInterface(bridge, "AndroidBridge");

        billing.start();
        consent.gather();

        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override public void handleOnBackPressed() { onBack(); }
        });

        if (savedInstanceState == null || web.restoreState(savedInstanceState) == null) web.loadUrl(START_URL);
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void configureWebView() {
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);            // localStorage: oyun kaydı
        s.setAllowFileAccess(false);             // file:// kapalı
        s.setAllowContentAccess(false);          // content:// kapalı
        s.setAllowFileAccessFromFileURLs(false);
        s.setAllowUniversalAccessFromFileURLs(false);
        s.setGeolocationEnabled(false);
        s.setSupportMultipleWindows(false);
        s.setJavaScriptCanOpenWindowsAutomatically(false);
        s.setMediaPlaybackRequiresUserGesture(false); // Web Audio sesleri
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setDisplayZoomControls(false);
        s.setTextZoom(100);                      // oyun kendi yazı sığdırmasını yapar
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setCacheMode(WebSettings.LOAD_NO_CACHE); // dosyalar zaten APK içinde
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setHapticFeedbackEnabled(false);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG); // yalnızca debug'da chrome://inspect

        assetLoader = new WebViewAssetLoader.Builder()
                .setDomain(WebViewAssetLoader.DEFAULT_DOMAIN)
                .setHttpAllowed(false)
                .addPathHandler("/", new WwwPathHandler(getAssets()))
                .build();

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                WebResourceResponse r = assetLoader.shouldInterceptRequest(request.getUrl());
                if (r != null) return r;
                // Paket dışı hiçbir kaynak yüklenmez (oyunun CSP'si de connect-src 'none').
                return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found",
                        Collections.<String, String>emptyMap(), new ByteArrayInputStream(new byte[0]));
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return handleNavigation(request.getUrl());
            }

            @Override
            public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
                // WebView işlemi çöktüyse uygulamayı çökertmeden yeniden kur (kayıt localStorage'da güvende).
                if (view == web) {
                    root.removeView(web);
                    web.destroy();
                    web = null;
                    recreate();
                }
                return true;
            }
        });
    }

    /** true = WebView bu adrese GİTMEZ. */
    boolean handleNavigation(Uri uri) {
        if (uri == null) return true;
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(java.util.Locale.ROOT);
        if ("https".equals(scheme) && WebViewAssetLoader.DEFAULT_DOMAIN.equalsIgnoreCase(uri.getHost())) {
            return false; // oyunun kendi sayfaları
        }
        if ("mailto".equals(scheme)) {
            openExternal(new Intent(Intent.ACTION_SENDTO, uri));
            return true;
        }
        if ("https".equals(scheme) && isAllowedExternal(uri.toString())) {
            openExternal(new Intent(Intent.ACTION_VIEW, uri));
            return true;
        }
        return true; // diğer her şey engellenir
    }

    private boolean isAllowedExternal(String url) {
        String privacy = getString(R.string.privacy_policy_url);
        if (privacy.isEmpty() || !privacy.startsWith("https://")) return false;
        String base = privacy.contains("?") ? privacy.substring(0, privacy.indexOf('?')) : privacy;
        return url.equals(privacy) || url.equals(base) || url.startsWith(base + "?") || url.startsWith(base + "#");
    }

    private void openExternal(Intent intent) {
        try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(this, R.string.link_open_failed, Toast.LENGTH_SHORT).show();
        }
    }

    /** Geri tuşu/hareketi oyuna iletilir; oyun 'exit' derse (ana menü) uygulamadan çıkılır. */
    private void onBack() {
        if (web == null) { finish(); return; }
        web.evaluateJavascript(BACK_JS, new android.webkit.ValueCallback<String>() {
            @Override public void onReceiveValue(String value) {
                if (value == null || "\"exit\"".equals(value) || "null".equals(value)) finish();
            }
        });
    }

    // ------------------------------------------------------------------ yaşam döngüsü

    @Override protected void onResume() {
        super.onResume();
        if (web != null) { web.onResume(); web.resumeTimers(); }
        if (billing != null) billing.onResume();
        if (ads != null) ads.onResume();
    }

    @Override protected void onPause() {
        if (web != null) { web.onPause(); web.pauseTimers(); }
        super.onPause();
    }

    @Override protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (web != null) web.saveState(outState);
    }

    @Override protected void onDestroy() {
        destroyed = true;
        main.removeCallbacksAndMessages(null);
        if (ads != null) ads.destroy();
        if (billing != null) billing.end();
        if (web != null) {
            web.removeJavascriptInterface("AndroidBridge");
            root.removeView(web);
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }

    // ------------------------------------------------------------------ AndroidBridge.Host

    @Override public void runOnUi(Runnable r) {
        if (Looper.myLooper() == Looper.getMainLooper()) r.run();
        else main.post(r);
    }

    @Override public void evaluateJs(String script) {
        if (web != null && !destroyed) web.evaluateJavascript(script, null);
    }

    @Override public boolean isOnline() {
        try {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) return false;
            Network n = cm.getActiveNetwork();
            if (n == null) return false;
            NetworkCapabilities c = cm.getNetworkCapabilities(n);
            return c != null && c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    && c.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED);
        } catch (RuntimeException e) {
            return false;
        }
    }

    @Override public void vibrate(long[] pattern) {
        try {
            Vibrator v;
            if (Build.VERSION.SDK_INT >= 31) {
                VibratorManager vm = (VibratorManager) getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
                v = vm == null ? null : vm.getDefaultVibrator();
            } else {
                v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            }
            if (v == null || !v.hasVibrator()) return;
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createWaveform(pattern, -1));
            else v.vibrate(pattern, -1);
        } catch (RuntimeException ignored) {
            // titreşim kritik değil
        }
    }

    @Override public void setSystemBarsDark(boolean dark) {
        int bg = getColor(dark ? R.color.app_bg_dark : R.color.app_bg_light);
        root.setBackgroundColor(bg);
        if (web != null) web.setBackgroundColor(bg);
        getWindow().getDecorView().setBackgroundColor(bg);
        WindowInsetsControllerCompat c = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        c.setAppearanceLightStatusBars(!dark);
        c.setAppearanceLightNavigationBars(!dark);
    }
}
