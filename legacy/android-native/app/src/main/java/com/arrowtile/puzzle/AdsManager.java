package com.arrowtile.puzzle;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardItem;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.gms.ads.OnUserEarnedRewardListener;
import com.google.android.gms.ads.initialization.InitializationStatus;
import com.google.android.gms.ads.initialization.OnInitializationCompleteListener;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * AdMob geçiş + ödüllü reklam: önceden yükleme, süresi dolanı yenileme, başarısız yüklemede artan bekleme.
 * Ne zaman reklam gösterileceğine (sıklık, bölüm 1 reklamsız, 3 dk aralık) JS katmanı (ads.js) karar verir;
 * burası yalnızca "hazır mı" ve "göster" sağlar. initialize() yalnızca UMP canRequestAds() sonrası çağrılır.
 */
public final class AdsManager implements AndroidBridge.Ads {

    private static final String TAG = "ArrowtileAds";
    /** AdMob: yüklenen tam ekran reklam ~1 saat geçerlidir; biraz önce yenilenir. */
    private static final long MAX_AGE_MS = 55L * 60L * 1000L;
    private static final long RETRY_MIN_MS = 15_000L;
    private static final long RETRY_MAX_MS = 10L * 60L * 1000L;
    /** Ödül olayı nadiren kapanıştan sonra gelir; kapanışı kısa süre geciktirerek ödülün kaybolmasını önleriz. */
    private static final long CLOSE_DELAY_MS = 350L;

    private final Activity activity;
    private final String interstitialId;
    private final String rewardedId;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AtomicBoolean started = new AtomicBoolean(false);

    private volatile boolean sdkReady = false;
    private volatile InterstitialAd interstitial;
    private volatile long interstitialAt;
    private volatile RewardedAd rewarded;
    private volatile long rewardedAt;
    private boolean loadingInterstitial = false;
    private boolean loadingRewarded = false;
    private long interstitialRetry = RETRY_MIN_MS;
    private long rewardedRetry = RETRY_MIN_MS;
    private long interstitialNextAt = 0;
    private long rewardedNextAt = 0;
    private boolean showing = false;
    private boolean destroyed = false;

    public AdsManager(Activity activity) {
        this.activity = activity;
        this.interstitialId = activity.getString(R.string.admob_interstitial_id);
        this.rewardedId = activity.getString(R.string.admob_rewarded_id);
    }

    /** UMP onayı reklam isteğine izin verdikten sonra bir kez çağrılır (ana iş parçacığı). */
    public void initialize() {
        if (!started.compareAndSet(false, true)) return;
        // Genel kitleye uygun reklam içeriği (oyun "her yaş" kitleye hitap ediyor; çocuklara yönelik değil).
        MobileAds.setRequestConfiguration(new RequestConfiguration.Builder()
                .setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_PG)
                .build());
        // Google önerisi: başlatmayı arka plan iş parçacığında yap.
        new Thread(new Runnable() {
            @Override public void run() {
                MobileAds.initialize(activity.getApplicationContext(), new OnInitializationCompleteListener() {
                    @Override public void onInitializationComplete(InitializationStatus status) {
                        main.post(new Runnable() {
                            @Override public void run() {
                                sdkReady = true;
                                loadInterstitial();
                                loadRewarded();
                            }
                        });
                    }
                });
            }
        }, "ads-init").start();
    }

    public void onResume() {
        if (!sdkReady || destroyed) return;
        if (interstitial == null || expired(interstitialAt)) loadInterstitial();
        if (rewarded == null || expired(rewardedAt)) loadRewarded();
    }

    public void destroy() {
        destroyed = true;
        main.removeCallbacksAndMessages(null);
        interstitial = null;
        rewarded = null;
    }

    // ------------------------------------------------------------------ AndroidBridge.Ads

    @Override public boolean isInterstitialReady() {
        boolean ok = sdkReady && interstitial != null && !expired(interstitialAt);
        if (!ok && sdkReady) main.post(new Runnable() { @Override public void run() { loadInterstitial(); } });
        return ok;
    }

    @Override public boolean isRewardedReady() {
        boolean ok = sdkReady && rewarded != null && !expired(rewardedAt);
        if (!ok && sdkReady) main.post(new Runnable() { @Override public void run() { loadRewarded(); } });
        return ok;
    }

    @Override public void showInterstitial(final AndroidBridge.AdCallbacks cb) {
        final InterstitialAd ad = interstitial;
        if (ad == null || showing || destroyed || activity.isFinishing()) { cb.onFailed(); return; }
        interstitial = null;
        showing = true;
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override public void onAdDismissedFullScreenContent() {
                showing = false;
                cb.onClosed();
                loadInterstitial();
            }
            @Override public void onAdFailedToShowFullScreenContent(AdError error) {
                showing = false;
                Log.w(TAG, "interstitial show failed: " + error.getMessage());
                cb.onFailed();
                loadInterstitial();
            }
        });
        ad.show(activity);
    }

    @Override public void showRewarded(final AndroidBridge.AdCallbacks cb) {
        final RewardedAd ad = rewarded;
        if (ad == null || showing || destroyed || activity.isFinishing()) { cb.onFailed(); return; }
        rewarded = null;
        showing = true;
        ad.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override public void onAdDismissedFullScreenContent() {
                showing = false;
                main.postDelayed(new Runnable() { @Override public void run() { cb.onClosed(); } }, CLOSE_DELAY_MS);
                loadRewarded();
            }
            @Override public void onAdFailedToShowFullScreenContent(AdError error) {
                showing = false;
                Log.w(TAG, "rewarded show failed: " + error.getMessage());
                cb.onFailed();
                loadRewarded();
            }
        });
        ad.show(activity, new OnUserEarnedRewardListener() {
            @Override public void onUserEarnedReward(RewardItem item) {
                main.post(new Runnable() { @Override public void run() { cb.onRewarded(); } });
            }
        });
    }

    // ------------------------------------------------------------------ yükleme

    private static boolean expired(long loadedAt) {
        return loadedAt > 0 && SystemClock.elapsedRealtime() - loadedAt > MAX_AGE_MS;
    }

    private void loadInterstitial() {
        if (!sdkReady || destroyed || loadingInterstitial) return;
        if (SystemClock.elapsedRealtime() < interstitialNextAt) return; // başarısız yüklemeden sonra bekleme süresi
        if (interstitial != null && !expired(interstitialAt)) return;
        loadingInterstitial = true;
        InterstitialAd.load(activity, interstitialId, new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
            @Override public void onAdLoaded(InterstitialAd ad) {
                loadingInterstitial = false;
                interstitial = ad;
                interstitialAt = SystemClock.elapsedRealtime();
                interstitialRetry = RETRY_MIN_MS;
            }
            @Override public void onAdFailedToLoad(LoadAdError error) {
                loadingInterstitial = false;
                interstitial = null;
                Log.i(TAG, "interstitial load failed (" + error.getCode() + "): " + error.getMessage());
                final long wait = interstitialRetry;
                interstitialRetry = Math.min(RETRY_MAX_MS, interstitialRetry * 2);
                interstitialNextAt = SystemClock.elapsedRealtime() + wait;
                main.postDelayed(new Runnable() { @Override public void run() { loadInterstitial(); } }, wait);
            }
        });
    }

    private void loadRewarded() {
        if (!sdkReady || destroyed || loadingRewarded) return;
        if (SystemClock.elapsedRealtime() < rewardedNextAt) return; // başarısız yüklemeden sonra bekleme süresi
        if (rewarded != null && !expired(rewardedAt)) return;
        loadingRewarded = true;
        RewardedAd.load(activity, rewardedId, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override public void onAdLoaded(RewardedAd ad) {
                loadingRewarded = false;
                rewarded = ad;
                rewardedAt = SystemClock.elapsedRealtime();
                rewardedRetry = RETRY_MIN_MS;
            }
            @Override public void onAdFailedToLoad(LoadAdError error) {
                loadingRewarded = false;
                rewarded = null;
                Log.i(TAG, "rewarded load failed (" + error.getCode() + "): " + error.getMessage());
                final long wait = rewardedRetry;
                rewardedRetry = Math.min(RETRY_MAX_MS, rewardedRetry * 2);
                rewardedNextAt = SystemClock.elapsedRealtime() + wait;
                main.postDelayed(new Runnable() { @Override public void run() { loadRewarded(); } }, wait);
            }
        });
    }
}
