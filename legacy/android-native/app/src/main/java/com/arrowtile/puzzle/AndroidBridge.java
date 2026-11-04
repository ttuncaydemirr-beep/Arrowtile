package com.arrowtile.puzzle;

import android.webkit.JavascriptInterface;

/**
 * window.AndroidBridge — game/js/ads.js'in beklediği yerel köprü (birebir aynı ad ve imzalar).
 *
 * ads.js sözleşmesi (game/js/ads.js başlık yorumu):
 *  isAdFree(): boolean
 *  isOnline(): boolean
 *  isRewardedReady(): boolean
 *  showInterstitial(id: number): boolean   → bitince onNative({id, event:'closed'}) (gösterilemezse 'failed')
 *  showRewarded(id: number, placement: string): boolean → {id,'rewarded'} sonra {id,'closed'}
 *  purchaseRemoveAds(id: number): boolean  → {id, event:'purchased'|'pending'|'cancelled'|'failed'}
 *  restorePurchases(id: number): boolean   → {id, event:'restored', adFree: boolean} (hata: 'failed')
 * Ek (Gizlilik seçenekleri, UMP):
 *  privacyOptionsRequired(): boolean
 *  showPrivacyOptions(id: number): boolean → form kapanınca {id, event:'closed'}
 * Ek (kabuk):
 *  vibrate(pattern: string)  — "30" ya da "[30,40,30]" (navigator.vibrate biçimi)
 *  setSystemBarsDark(dark: boolean) — oyun içi Açık/Koyu seçimine göre durum çubuğu simgeleri
 *
 * Sonuçlar ana iş parçacığında evaluateJavascript ile şu biçimde iletilir:
 *   window.Monetization.onNative('{"id":3,"event":"closed"}')
 *
 * @JavascriptInterface metodları WebView'in arka plan iş parçacığında çağrılır: burada yalnızca
 * iş parçacığı güvenli okumalar yapılır, SDK çağrıları Host.runOnUi ile ana iş parçacığına aktarılır.
 */
public final class AndroidBridge {

    /** Etkinlik (MainActivity) tarafından sağlanan kabuk işlevleri. */
    public interface Host {
        void runOnUi(Runnable r);
        /** Ana iş parçacığında çağrılır. */
        void evaluateJs(String script);
        boolean isOnline();
        void vibrate(long[] pattern);
        void setSystemBarsDark(boolean dark);
    }

    /** Tam ekran reklam olayları (ana iş parçacığında). */
    public interface AdCallbacks {
        void onRewarded();
        void onClosed();
        void onFailed();
    }

    public interface Ads {
        boolean isInterstitialReady();
        boolean isRewardedReady();
        /** Ana iş parçacığında çağrılır. */
        void showInterstitial(AdCallbacks cb);
        /** Ana iş parçacığında çağrılır. */
        void showRewarded(AdCallbacks cb);
    }

    /** Satın alma sonucu: event = purchased | pending | cancelled | failed | restored. */
    public interface BillingResultCallback {
        void onResult(String event, boolean adFree);
    }

    public interface Billing {
        boolean isAdFree();
        void purchaseRemoveAds(BillingResultCallback cb);
        void restorePurchases(BillingResultCallback cb);
    }

    public interface Consent {
        boolean isPrivacyOptionsRequired();
        /** Ana iş parçacığında çağrılır; form kapanınca onDone. */
        void showPrivacyOptions(Runnable onDone);
    }

    private final Host host;
    private final Ads ads;
    private final Billing billing;
    private final Consent consent;

    public AndroidBridge(Host host, Ads ads, Billing billing, Consent consent) {
        this.host = host;
        this.ads = ads;
        this.billing = billing;
        this.consent = consent;
    }

    // ------------------------------------------------------------------ ads.js API

    @JavascriptInterface
    public boolean isAdFree() {
        return billing.isAdFree();
    }

    @JavascriptInterface
    public boolean isOnline() {
        return host.isOnline();
    }

    @JavascriptInterface
    public boolean isRewardedReady() {
        return host.isOnline() && ads.isRewardedReady();
    }

    @JavascriptInterface
    public boolean showInterstitial(final int id) {
        if (!host.isOnline() || !ads.isInterstitialReady()) return false;
        host.runOnUi(new Runnable() {
            @Override public void run() {
                ads.showInterstitial(new OneShot(id, false));
            }
        });
        return true;
    }

    @JavascriptInterface
    public boolean showRewarded(final int id, String placement) {
        if (!host.isOnline() || !ads.isRewardedReady()) return false;
        host.runOnUi(new Runnable() {
            @Override public void run() {
                ads.showRewarded(new OneShot(id, true));
            }
        });
        return true;
    }

    @JavascriptInterface
    public boolean purchaseRemoveAds(final int id) {
        if (!host.isOnline()) return false; // ads.js → "İnternet bağlantısı yok"
        host.runOnUi(new Runnable() {
            @Override public void run() {
                billing.purchaseRemoveAds(new BillingResultCallback() {
                    private boolean sent = false;
                    @Override public void onResult(String event, boolean adFree) {
                        if (sent) return;
                        sent = true;
                        emit(id, normalizePurchaseEvent(event), null);
                    }
                });
            }
        });
        return true;
    }

    @JavascriptInterface
    public boolean restorePurchases(final int id) {
        host.runOnUi(new Runnable() {
            @Override public void run() {
                billing.restorePurchases(new BillingResultCallback() {
                    private boolean sent = false;
                    @Override public void onResult(String event, boolean adFree) {
                        if (sent) return;
                        sent = true;
                        if ("restored".equals(event)) emit(id, "restored", adFree);
                        else emit(id, "failed", null);
                    }
                });
            }
        });
        return true;
    }

    // ------------------------------------------------------------------ UMP gizlilik seçenekleri

    @JavascriptInterface
    public boolean privacyOptionsRequired() {
        return consent.isPrivacyOptionsRequired();
    }

    @JavascriptInterface
    public boolean showPrivacyOptions(final int id) {
        if (!consent.isPrivacyOptionsRequired()) return false;
        host.runOnUi(new Runnable() {
            @Override public void run() {
                consent.showPrivacyOptions(new Runnable() {
                    private boolean sent = false;
                    @Override public void run() {
                        if (sent) return;
                        sent = true;
                        emit(id, "closed", null);
                    }
                });
            }
        });
        return true;
    }

    // ------------------------------------------------------------------ kabuk

    @JavascriptInterface
    public void vibrate(String pattern) {
        long[] p = parsePattern(pattern);
        if (p != null) host.vibrate(p);
    }

    @JavascriptInterface
    public void setSystemBarsDark(final boolean dark) {
        host.runOnUi(new Runnable() {
            @Override public void run() { host.setSystemBarsDark(dark); }
        });
    }

    // ------------------------------------------------------------------ yardımcılar

    /** Yerelden kendiliğinden gelen durum değişikliği (ör. bekleyen satın alma tamamlandı, onay güncellendi). */
    public void notifyStateChanged() {
        host.runOnUi(new Runnable() {
            @Override public void run() {
                host.evaluateJs("window.ArrowtileApp&&window.ArrowtileApp.refresh&&window.ArrowtileApp.refresh()");
            }
        });
    }

    static String normalizePurchaseEvent(String event) {
        if ("purchased".equals(event) || "pending".equals(event) || "cancelled".equals(event)) return event;
        return "failed";
    }

    /** {"id":3,"event":"closed"} / {"id":4,"event":"restored","adFree":true}. Değerler sabit: kaçış gerekmez. */
    static String json(int id, String event, Boolean adFree) {
        StringBuilder sb = new StringBuilder(48);
        sb.append("{\"id\":").append(id).append(",\"event\":\"").append(event).append('"');
        if (adFree != null) sb.append(",\"adFree\":").append(adFree.booleanValue() ? "true" : "false");
        return sb.append('}').toString();
    }

    static String onNativeScript(int id, String event, Boolean adFree) {
        // JSON yalnızca rakam, sabit olay adı ve true/false içerir; tek tırnak ya da ters bölü yoktur.
        return "window.Monetization&&window.Monetization.onNative('" + json(id, event, adFree) + "')";
    }

    private void emit(final int id, final String event, final Boolean adFree) {
        host.runOnUi(new Runnable() {
            @Override public void run() { host.evaluateJs(onNativeScript(id, event, adFree)); }
        });
    }

    /** navigator.vibrate biçimi [titreşim, ara, titreşim, ...] → Android dalga biçimi [bekle, titreşim, ara, ...]. */
    static long[] parsePattern(String s) {
        if (s == null) return null;
        String t = s.trim();
        if (t.startsWith("[")) t = t.substring(1);
        if (t.endsWith("]")) t = t.substring(0, t.length() - 1);
        if (t.trim().isEmpty()) return null;
        String[] parts = t.split(",");
        if (parts.length > 32) return null;
        long[] out = new long[parts.length + 1];
        out[0] = 0;
        long total = 0;
        for (int i = 0; i < parts.length; i++) {
            long v;
            try { v = Math.round(Double.parseDouble(parts[i].trim())); } catch (NumberFormatException e) { return null; }
            if (v < 0) v = 0;
            if (v > 2000) v = 2000;
            out[i + 1] = v;
            total += v;
        }
        return total > 0 ? out : null;
    }

    /** Bir reklam gösterimi için tek seferlik olay iletici: 'closed'/'failed' yalnızca bir kez gider. */
    private final class OneShot implements AdCallbacks {
        private final int id;
        private final boolean rewardedAd;
        private boolean finished = false;
        private boolean rewardSent = false;

        OneShot(int id, boolean rewardedAd) { this.id = id; this.rewardedAd = rewardedAd; }

        @Override public void onRewarded() {
            if (!rewardedAd || finished || rewardSent) return;
            rewardSent = true;
            emit(id, "rewarded", null);
        }
        @Override public void onClosed() {
            if (finished) return;
            finished = true;
            emit(id, "closed", null);
        }
        @Override public void onFailed() {
            if (finished) return;
            finished = true;
            emit(id, "failed", null);
        }
    }
}
