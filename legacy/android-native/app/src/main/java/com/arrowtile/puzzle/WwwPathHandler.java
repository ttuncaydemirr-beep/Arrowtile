package com.arrowtile.puzzle;

import android.content.res.AssetManager;
import android.webkit.WebResourceResponse;

import androidx.webkit.WebViewAssetLoader;

import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;

/**
 * https://appassets.androidplatform.net/<yol> → APK içindeki assets/www/<yol>.
 * (WebViewAssetLoader.AssetsPathHandler assets/ kökünü sunar; biz yalnızca www/ alt klasörünü açarız.)
 */
public final class WwwPathHandler implements WebViewAssetLoader.PathHandler {

    private static final String ROOT = "www/";
    private final AssetManager assets;

    public WwwPathHandler(AssetManager assets) {
        this.assets = assets;
    }

    @Override
    public WebResourceResponse handle(String path) {
        String p = normalize(path);
        if (p == null) return null;
        try {
            InputStream in = assets.open(ROOT + p);
            String mime = mimeOf(p);
            String enc = mime.startsWith("text/") || mime.endsWith("javascript") || mime.endsWith("json")
                    || mime.endsWith("svg+xml") ? "utf-8" : null;
            return new WebResourceResponse(mime, enc, in);
        } catch (IOException e) {
            return null;
        }
    }

    /** "", "/" → index.html; ".." ya da ters bölü içeren yollar reddedilir. */
    static String normalize(String path) {
        if (path == null) return null;
        String p = path;
        int q = p.indexOf('?');
        if (q >= 0) p = p.substring(0, q);
        int h = p.indexOf('#');
        if (h >= 0) p = p.substring(0, h);
        while (p.startsWith("/")) p = p.substring(1);
        if (p.isEmpty()) p = "index.html";
        if (p.endsWith("/")) p = p + "index.html";
        if (p.contains("\\") || p.contains("\u0000")) return null;
        for (String seg : p.split("/")) {
            if (seg.equals("..") || seg.equals(".") || seg.isEmpty()) return null;
        }
        return p;
    }

    static String mimeOf(String p) {
        String l = p.toLowerCase(Locale.ROOT);
        if (l.endsWith(".html") || l.endsWith(".htm")) return "text/html";
        if (l.endsWith(".js") || l.endsWith(".mjs")) return "text/javascript";
        if (l.endsWith(".css")) return "text/css";
        if (l.endsWith(".svg")) return "image/svg+xml";
        if (l.endsWith(".png")) return "image/png";
        if (l.endsWith(".jpg") || l.endsWith(".jpeg")) return "image/jpeg";
        if (l.endsWith(".webp")) return "image/webp";
        if (l.endsWith(".json")) return "application/json";
        if (l.endsWith(".woff2")) return "font/woff2";
        if (l.endsWith(".woff")) return "font/woff";
        if (l.endsWith(".ttf")) return "font/ttf";
        if (l.endsWith(".mp3")) return "audio/mpeg";
        if (l.endsWith(".ogg")) return "audio/ogg";
        if (l.endsWith(".wav")) return "audio/wav";
        if (l.endsWith(".txt")) return "text/plain";
        return "application/octet-stream";
    }
}
