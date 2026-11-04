package com.arrowtile.puzzle;

import android.app.Activity;
import android.util.Log;

import com.google.android.ump.ConsentDebugSettings;
import com.google.android.ump.ConsentForm;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.FormError;
import com.google.android.ump.UserMessagingPlatform;

/**
 * UMP (User Messaging Platform): her açılışta onay bilgisi güncellenir, gerekiyorsa (AEA, BK, İsviçre, bazı ABD
 * eyaletleri) form gösterilir; reklam SDK'sı ancak canRequestAds() true olduktan sonra başlatılır.
 * Ayarlar'daki "Gizlilik seçenekleri" düğmesi showPrivacyOptions() ile formu yeniden açar.
 */
public final class ConsentManager implements AndroidBridge.Consent {

    private static final String TAG = "ArrowtileConsent";

    public interface Listener {
        /** canRequestAds() true olduğunda (birden çok kez çağrılabilir; alıcı tekrarı yok saymalı). */
        void onCanRequestAds();
        /** Gizlilik seçenekleri gerekliliği değişti (Ayarlar ekranı yenilensin). */
        void onPrivacyOptionsChanged();
    }

    private final Activity activity;
    private final ConsentInformation info;
    private final Listener listener;
    private volatile boolean privacyOptionsRequired = false;

    public ConsentManager(Activity activity, Listener listener) {
        this.activity = activity;
        this.listener = listener;
        this.info = UserMessagingPlatform.getConsentInformation(activity);
    }

    /** Uygulama açılışında (onCreate) çağrılır. */
    public void gather() {
        ConsentRequestParameters.Builder params = new ConsentRequestParameters.Builder()
                .setTagForUnderAgeOfConsent(false);
        if (BuildConfig.DEBUG) {
            String testId = activity.getString(R.string.ump_test_device_hashed_id);
            boolean eea = activity.getResources().getBoolean(R.bool.ump_debug_geography_eea);
            if (eea || (testId != null && !testId.isEmpty())) {
                ConsentDebugSettings.Builder dbg = new ConsentDebugSettings.Builder(activity);
                if (eea) dbg.setDebugGeography(ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA);
                if (testId != null && !testId.isEmpty()) dbg.addTestDeviceHashedId(testId);
                params.setConsentDebugSettings(dbg.build());
            }
        }
        info.requestConsentInfoUpdate(activity, params.build(),
                new ConsentInformation.OnConsentInfoUpdateSuccessListener() {
                    @Override public void onConsentInfoUpdateSuccess() {
                        UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity,
                                new ConsentForm.OnConsentFormDismissedListener() {
                                    @Override public void onConsentFormDismissed(FormError formError) {
                                        if (formError != null) Log.w(TAG, "form: " + formError.getMessage());
                                        afterUpdate();
                                    }
                                });
                    }
                },
                new ConsentInformation.OnConsentInfoUpdateFailureListener() {
                    @Override public void onConsentInfoUpdateFailure(FormError requestError) {
                        Log.w(TAG, "update: " + requestError.getMessage());
                        afterUpdate();
                    }
                });
        // Önceki oturumda alınmış onay varsa reklamlar beklemeden başlayabilir.
        refreshFlags();
        if (info.canRequestAds()) listener.onCanRequestAds();
    }

    private void afterUpdate() {
        refreshFlags();
        if (info.canRequestAds()) listener.onCanRequestAds();
    }

    private void refreshFlags() {
        boolean req = info.getPrivacyOptionsRequirementStatus()
                == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
        if (req != privacyOptionsRequired) {
            privacyOptionsRequired = req;
            listener.onPrivacyOptionsChanged();
        }
    }

    public boolean canRequestAds() {
        return info.canRequestAds();
    }

    // ------------------------------------------------------------------ AndroidBridge.Consent

    @Override public boolean isPrivacyOptionsRequired() {
        return privacyOptionsRequired;
    }

    @Override public void showPrivacyOptions(final Runnable onDone) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity, new ConsentForm.OnConsentFormDismissedListener() {
            @Override public void onConsentFormDismissed(FormError formError) {
                if (formError != null) Log.w(TAG, "privacy options: " + formError.getMessage());
                afterUpdate();
                onDone.run();
            }
        });
    }
}
