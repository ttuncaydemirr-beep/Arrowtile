package com.arrowtile.puzzle

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // UMP (Google Kullanıcı Mesajlaşma Platformu), TCF tercihlerini varsayılan SharedPreferences'a yazar (IABTCF_*).
    // Flutter tarafı bunları yalnızca Firebase Analytics onay sinyallerini (Consent Mode) türetmek için okur (docs/19).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.arrowtile.puzzle/consent")
            .setMethodCallHandler { call, result ->
                if (call.method == "tcf") {
                    try {
                        val sp = applicationContext.getSharedPreferences(applicationContext.packageName + "_preferences", Context.MODE_PRIVATE) // varsayılan tercih dosyası
                        val applies = try { sp.getInt("IABTCF_gdprApplies", 0) } catch (e: Exception) { 0 }
                        val purposes = try { sp.getString("IABTCF_PurposeConsents", "") ?: "" } catch (e: Exception) { "" }
                        result.success(mapOf("gdprApplies" to applies, "purposeConsents" to purposes))
                    } catch (e: Exception) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
