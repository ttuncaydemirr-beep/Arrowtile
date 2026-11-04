package com.arrowtile.puzzle;

import java.util.ArrayList;
import java.util.List;

/** Sahte Host/Ads/Billing/Consent ile AndroidBridge mantığını çalıştırır; üretilen JS betiklerini yazdırır. */
public class BridgeHarness {
    static List<String> scripts = new ArrayList<>();
    static int fails = 0;
    static void check(String name, boolean ok) { System.err.println((ok ? "GEÇTİ  " : "KALDI  ") + name); if (!ok) fails++; }

    public static void main(String[] a) {
        final boolean[] ready = { false };
        final String[] nextPurchase = { "pending" };
        AndroidBridge.Host host = new AndroidBridge.Host() {
            public void runOnUi(Runnable r) { r.run(); }
            public void evaluateJs(String s) { scripts.add(s); }
            public boolean isOnline() { return true; }
            public void vibrate(long[] p) { }
            public void setSystemBarsDark(boolean d) { }
        };
        AndroidBridge.Ads ads = new AndroidBridge.Ads() {
            public boolean isInterstitialReady() { return ready[0]; }
            public boolean isRewardedReady() { return ready[0]; }
            public void showInterstitial(AndroidBridge.AdCallbacks cb) { cb.onClosed(); cb.onClosed(); cb.onFailed(); }
            public void showRewarded(AndroidBridge.AdCallbacks cb) { cb.onRewarded(); cb.onRewarded(); cb.onClosed(); }
        };
        AndroidBridge.Billing billing = new AndroidBridge.Billing() {
            public boolean isAdFree() { return false; }
            public void purchaseRemoveAds(AndroidBridge.BillingResultCallback cb) { cb.onResult(nextPurchase[0], false); cb.onResult("purchased", true); }
            public void restorePurchases(AndroidBridge.BillingResultCallback cb) { cb.onResult("restored", true); }
        };
        AndroidBridge.Consent consent = new AndroidBridge.Consent() {
            public boolean isPrivacyOptionsRequired() { return true; }
            public void showPrivacyOptions(Runnable done) { done.run(); done.run(); }
        };
        AndroidBridge b = new AndroidBridge(host, ads, billing, consent);

        check("reklam hazır değilken showInterstitial false döner", !b.showInterstitial(99) && scripts.isEmpty());
        check("reklam hazır değilken isRewardedReady false", !b.isRewardedReady());
        ready[0] = true;
        check("showInterstitial(1) true", b.showInterstitial(1));
        check("showRewarded(2) true", b.showRewarded(2, "life"));
        nextPurchase[0] = "pending";   check("purchase(3) true", b.purchaseRemoveAds(3));
        check("showPrivacyOptions(4) true", b.showPrivacyOptions(4));
        nextPurchase[0] = "error-xyz"; check("purchase(5) true", b.purchaseRemoveAds(5));
        nextPurchase[0] = "purchased"; check("purchase(6) true", b.purchaseRemoveAds(6));
        check("restore(7) true", b.restorePurchases(7));

        long[] p = AndroidBridge.parsePattern("[30,40,30]");
        check("titreşim deseni [30,40,30] → [0,30,40,30]", p != null && p.length == 4 && p[0] == 0 && p[1] == 30 && p[2] == 40 && p[3] == 30);
        check("titreşim tek sayı \"8\" → [0,8]", java.util.Arrays.equals(AndroidBridge.parsePattern("8"), new long[]{0, 8}));
        check("titreşim bozuk girdi reddedilir", AndroidBridge.parsePattern("\"button\"") == null && AndroidBridge.parsePattern(null) == null && AndroidBridge.parsePattern("[]") == null);
        check("yol: '' → index.html", "index.html".equals(WwwPathHandler.normalize("")));
        check("yol: js/main.js", "js/main.js".equals(WwwPathHandler.normalize("js/main.js")));
        check("yol: sorgu atılır", "index.html".equals(WwwPathHandler.normalize("index.html?debug=1")));
        check("yol: ../ reddedilir", WwwPathHandler.normalize("../AndroidManifest.xml") == null && WwwPathHandler.normalize("js/../../x") == null);
        check("mime: js/css/svg", WwwPathHandler.mimeOf("a.js").equals("text/javascript") && WwwPathHandler.mimeOf("a.CSS").equals("text/css") && WwwPathHandler.mimeOf("i.svg").equals("image/svg+xml"));

        for (String s : scripts) System.out.println(s);
        System.err.println(fails == 0 ? "Java köprü testi: hepsi geçti" : fails + " KALDI");
        System.exit(fails == 0 ? 0 : 1);
    }
}
