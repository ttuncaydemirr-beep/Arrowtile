package com.arrowtile.puzzle;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.AcknowledgePurchaseResponseListener;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.ProductDetailsResponseListener;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesResponseListener;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryProductDetailsResult;
import com.android.billingclient.api.QueryPurchasesParams;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Google Play Billing: tüketilmeyen tek ürün "remove_ads".
 *  - Açılışta (bağlantı kurulunca) ve her onResume'da queryPurchasesAsync ile sahiplik denetlenir.
 *  - PURCHASED → hak verilir, onaylanmamışsa acknowledge edilir (3 gün içinde onaylanmayan satın alma iade edilir).
 *  - PENDING → hak VERİLMEZ, onaylanmaz; oyuncuya "ödeme bekleniyor" denir. Tamamlanınca (uygulama açıkken
 *    onPurchasesUpdated, kapalıyken bir sonraki açılış/onResume sorgusu) hak verilir ve onaylanır.
 *  - Sonuç SharedPreferences'ta saklanır (çevrimdışı açılışta isAdFree() hemen doğru yanıt verir).
 * Not: Sunucu doğrulaması yoktur (tek kişilik, sunucusuz oyun). İleride sunucu eklenirse purchaseToken
 * Google Play Developer API ile doğrulanmalıdır.
 */
public final class BillingManager implements AndroidBridge.Billing, PurchasesUpdatedListener {

    public static final String PRODUCT_ID = "remove_ads";
    private static final String TAG = "ArrowtileBilling";
    private static final String PREFS = "arrowtile.billing";
    private static final String KEY_AD_FREE = "remove_ads_owned";

    public interface Listener {
        /** Sahiplik değişti (ör. bekleyen satın alma tamamlandı, iade). Ana iş parçacığında. */
        void onAdFreeChanged(boolean adFree);
    }

    private final Activity activity;
    private final Listener listener;
    private final SharedPreferences prefs;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final BillingClient client;
    private volatile boolean adFree;
    private ProductDetails productDetails;
    private AndroidBridge.BillingResultCallback purchaseCallback;
    private final List<Runnable> whenReadyOk = new ArrayList<>();
    private final List<Runnable> whenReadyFail = new ArrayList<>();
    private boolean connecting = false;
    private boolean ended = false;

    public BillingManager(Activity activity, Listener listener) {
        this.activity = activity;
        this.listener = listener;
        this.prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        this.adFree = prefs.getBoolean(KEY_AD_FREE, false);
        this.client = BillingClient.newBuilder(activity)
                .setListener(this)
                .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                .enableAutoServiceReconnection()
                .build();
    }

    /** onCreate'te çağrılır: bağlan, ürünü ve sahipliği sorgula. */
    public void start() {
        whenReady(new Runnable() {
            @Override public void run() {
                queryProduct(null);
                refreshOwned(null);
            }
        }, null);
    }

    /** onResume: uygulama kapalıyken tamamlanan bekleyen satın almaları yakala. */
    public void onResume() {
        if (ended) return;
        if (client.isReady()) refreshOwned(null);
    }

    public void end() {
        ended = true;
        main.removeCallbacksAndMessages(null);
        try { client.endConnection(); } catch (RuntimeException ignored) { }
    }

    // ------------------------------------------------------------------ AndroidBridge.Billing

    @Override public boolean isAdFree() {
        return adFree;
    }

    @Override public void purchaseRemoveAds(final AndroidBridge.BillingResultCallback cb) {
        whenReady(new Runnable() {
            @Override public void run() {
                if (productDetails != null) { launch(productDetails, cb); return; }
                queryProduct(new ProductCallback() {
                    @Override public void onProduct(ProductDetails pd) {
                        if (pd == null) cb.onResult("failed", adFree);
                        else launch(pd, cb);
                    }
                });
            }
        }, new Runnable() {
            @Override public void run() { cb.onResult("failed", adFree); }
        });
    }

    @Override public void restorePurchases(final AndroidBridge.BillingResultCallback cb) {
        whenReady(new Runnable() {
            @Override public void run() {
                refreshOwned(new OwnedCallback() {
                    @Override public void onOwned(Boolean owned) {
                        if (owned == null) cb.onResult("failed", adFree);
                        else cb.onResult("restored", owned.booleanValue());
                    }
                });
            }
        }, new Runnable() {
            @Override public void run() { cb.onResult("failed", adFree); }
        });
    }

    // ------------------------------------------------------------------ satın alma akışı

    private void launch(ProductDetails pd, AndroidBridge.BillingResultCallback cb) {
        BillingFlowParams.ProductDetailsParams.Builder pdp = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(pd);
        List<ProductDetails.OneTimePurchaseOfferDetails> offers = pd.getOneTimePurchaseOfferDetailsList();
        if (offers != null && !offers.isEmpty()) pdp.setOfferToken(offers.get(0).getOfferToken());
        BillingFlowParams params = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(Collections.singletonList(pdp.build()))
                .build();
        if (purchaseCallback != null) { // önceki akış yanıtsız kaldıysa onu kapat
            AndroidBridge.BillingResultCallback old = purchaseCallback;
            purchaseCallback = null;
            old.onResult("failed", adFree);
        }
        purchaseCallback = cb;
        BillingResult r = client.launchBillingFlow(activity, params);
        int code = r.getResponseCode();
        if (code == BillingClient.BillingResponseCode.OK) return; // sonuç onPurchasesUpdated'da
        purchaseCallback = null;
        if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            refreshOwned(new OwnedCallback() {
                @Override public void onOwned(Boolean owned) {
                    cb.onResult(Boolean.TRUE.equals(owned) ? "purchased" : "failed", adFree);
                }
            });
        } else if (code == BillingClient.BillingResponseCode.USER_CANCELED) {
            cb.onResult("cancelled", adFree);
        } else {
            Log.w(TAG, "launchBillingFlow: " + code + " " + r.getDebugMessage());
            cb.onResult("failed", adFree);
        }
    }

    @Override public void onPurchasesUpdated(final BillingResult result, final List<Purchase> purchases) {
        // Kütüphane bu geri çağrıyı ana iş parçacığında yapar; yine de güvence için ana iş parçacığına aktar.
        main.post(new Runnable() {
            @Override public void run() { handlePurchasesUpdated(result, purchases); }
        });
    }

    private void handlePurchasesUpdated(BillingResult result, List<Purchase> purchases) {
        AndroidBridge.BillingResultCallback cb = purchaseCallback;
        purchaseCallback = null;
        int code = result.getResponseCode();
        if (code == BillingClient.BillingResponseCode.OK && purchases != null) {
            boolean purchased = false, pending = false;
            for (Purchase p : purchases) {
                if (!p.getProducts().contains(PRODUCT_ID)) continue;
                int state = p.getPurchaseState();
                if (state == Purchase.PurchaseState.PURCHASED) { grant(p); purchased = true; }
                else if (state == Purchase.PurchaseState.PENDING) pending = true;
            }
            if (cb != null) cb.onResult(purchased ? "purchased" : pending ? "pending" : "failed", adFree);
        } else if (code == BillingClient.BillingResponseCode.USER_CANCELED) {
            if (cb != null) cb.onResult("cancelled", adFree);
        } else if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            final AndroidBridge.BillingResultCallback c = cb;
            refreshOwned(new OwnedCallback() {
                @Override public void onOwned(Boolean owned) {
                    if (c != null) c.onResult(Boolean.TRUE.equals(owned) ? "purchased" : "failed", adFree);
                }
            });
        } else {
            Log.w(TAG, "onPurchasesUpdated: " + code + " " + result.getDebugMessage());
            if (cb != null) cb.onResult("failed", adFree);
        }
    }

    /** PURCHASED durumundaki satın alma: hakkı ver ve onaylanmamışsa onayla. PENDING için ASLA çağrılmaz. */
    private void grant(Purchase p) {
        setAdFree(true);
        if (!p.isAcknowledged()) acknowledge(p.getPurchaseToken(), 0);
    }

    private void acknowledge(final String token, final int attempt) {
        AcknowledgePurchaseParams params = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build();
        client.acknowledgePurchase(params, new AcknowledgePurchaseResponseListener() {
            @Override public void onAcknowledgePurchaseResponse(BillingResult r) {
                if (r.getResponseCode() == BillingClient.BillingResponseCode.OK) return;
                Log.w(TAG, "acknowledge failed: " + r.getResponseCode() + " " + r.getDebugMessage());
                // Başarısızsa artan beklemeyle birkaç kez dene; olmazsa sonraki açılıştaki sorgu yeniden dener.
                if (attempt < 4 && !ended) {
                    main.postDelayed(new Runnable() {
                        @Override public void run() { acknowledge(token, attempt + 1); }
                    }, 2000L << attempt);
                }
            }
        });
    }

    // ------------------------------------------------------------------ sorgular

    private interface ProductCallback { void onProduct(ProductDetails pd); }
    private interface OwnedCallback { void onOwned(Boolean owned); }

    private void queryProduct(final ProductCallback cb) {
        QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
                .setProductList(Collections.singletonList(QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(PRODUCT_ID)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()))
                .build();
        client.queryProductDetailsAsync(params, new ProductDetailsResponseListener() {
            @Override public void onProductDetailsResponse(final BillingResult r, final QueryProductDetailsResult res) {
                main.post(new Runnable() {
                    @Override public void run() {
                        ProductDetails found = null;
                        if (r.getResponseCode() == BillingClient.BillingResponseCode.OK && res != null) {
                            for (ProductDetails pd : res.getProductDetailsList()) {
                                if (PRODUCT_ID.equals(pd.getProductId())) found = pd;
                            }
                            if (found == null) Log.w(TAG, "'" + PRODUCT_ID + "' bulunamadı (Play Console'da etkin mi?)");
                        } else {
                            Log.w(TAG, "queryProductDetails: " + r.getResponseCode() + " " + r.getDebugMessage());
                        }
                        if (found != null) productDetails = found;
                        if (cb != null) cb.onProduct(found);
                    }
                });
            }
        });
    }

    /** owned: true/false = Play'in yanıtı, null = sorgu başarısız (kayıtlı değer korunur). */
    private void refreshOwned(final OwnedCallback cb) {
        client.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
                new PurchasesResponseListener() {
                    @Override public void onQueryPurchasesResponse(final BillingResult r, final List<Purchase> list) {
                        main.post(new Runnable() {
                            @Override public void run() {
                                if (r.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                                    Log.w(TAG, "queryPurchases: " + r.getResponseCode() + " " + r.getDebugMessage());
                                    if (cb != null) cb.onOwned(null);
                                    return;
                                }
                                boolean owned = false;
                                if (list != null) for (Purchase p : list) {
                                    if (!p.getProducts().contains(PRODUCT_ID)) continue;
                                    if (p.getPurchaseState() == Purchase.PurchaseState.PURCHASED) {
                                        owned = true;
                                        if (!p.isAcknowledged()) acknowledge(p.getPurchaseToken(), 0);
                                    }
                                }
                                setAdFree(owned);
                                if (cb != null) cb.onOwned(owned);
                            }
                        });
                    }
                });
    }

    private void setAdFree(boolean v) {
        if (v == adFree) return;
        adFree = v;
        prefs.edit().putBoolean(KEY_AD_FREE, v).apply();
        listener.onAdFreeChanged(v);
    }

    // ------------------------------------------------------------------ bağlantı

    /** Bağlıysa hemen ok; değilse bağlanıp ok/fail. Ana iş parçacığında çağrılır. */
    private void whenReady(Runnable ok, Runnable fail) {
        if (ended) { if (fail != null) fail.run(); return; }
        if (client.isReady()) { ok.run(); return; }
        whenReadyOk.add(ok);
        whenReadyFail.add(fail);
        if (connecting) return;
        connecting = true;
        client.startConnection(new BillingClientStateListener() {
            @Override public void onBillingSetupFinished(final BillingResult r) {
                main.post(new Runnable() {
                    @Override public void run() {
                        connecting = false;
                        boolean good = r.getResponseCode() == BillingClient.BillingResponseCode.OK;
                        if (!good) Log.w(TAG, "billing setup: " + r.getResponseCode() + " " + r.getDebugMessage());
                        List<Runnable> run = new ArrayList<>(good ? whenReadyOk : whenReadyFail);
                        whenReadyOk.clear();
                        whenReadyFail.clear();
                        for (Runnable x : run) if (x != null) x.run();
                    }
                });
            }
            @Override public void onBillingServiceDisconnected() {
                // enableAutoServiceReconnection(): kütüphane bir sonraki çağrıda kendiliğinden yeniden bağlanır.
                main.post(new Runnable() {
                    @Override public void run() {
                        if (!connecting) return;
                        connecting = false;
                        List<Runnable> run = new ArrayList<>(whenReadyFail);
                        whenReadyOk.clear();
                        whenReadyFail.clear();
                        for (Runnable x : run) if (x != null) x.run();
                    }
                });
            }
        });
    }
}
