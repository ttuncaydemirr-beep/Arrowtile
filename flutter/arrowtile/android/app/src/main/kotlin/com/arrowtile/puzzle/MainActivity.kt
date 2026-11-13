package com.arrowtile.puzzle

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 1.2.2 (docs/28): targetSdk 35+ için kenardan kenara geriye uyumluluk (Play: "Edge-to-edge may not display for all users").
    // enableEdgeToEdge, super.onCreate'ten ÖNCE çağrılır. FlutterActivity ComponentActivity ise androidx.activity yolu; değilse
    // (eski gömme) WindowCompat ile aynı sonuç. Çubuk renklerini Dart tarafı değil bu çağrı (saydam) belirler.
    override fun onCreate(savedInstanceState: Bundle?) {
        val self: Any = this
        if (self is ComponentActivity) {
            self.enableEdgeToEdge()
        } else {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // UMP (Google Kullanıcı Mesajlaşma Platformu), TCF tercihlerini varsayılan SharedPreferences'a yazar (IABTCF_*).
        // Flutter tarafı bunları yalnızca Firebase Analytics onay sinyallerini (Consent Mode) türetmek için okur (docs/19).
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
        // 1.1.4 (docs/21): Tanılama ekranındaki "Paylaş" — düz metni Android paylaşım penceresiyle gönderir (WhatsApp, e-posta…).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.arrowtile.puzzle/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "text") {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                        }
                        startActivity(Intent.createChooser(send, null))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
