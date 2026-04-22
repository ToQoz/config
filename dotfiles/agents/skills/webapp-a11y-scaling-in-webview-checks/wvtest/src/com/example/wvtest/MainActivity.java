package com.example.wvtest;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.util.Log;
import java.lang.reflect.Method;

public class MainActivity extends Activity {
    private static final String TAG = "wvtest";

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        WebView wv = new WebView(this);
        wv.setWebViewClient(new WebViewClient());
        WebSettings s = wv.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        WebView.setWebContentsDebuggingEnabled(true);

        Intent i = getIntent();

        // --ei zoom N => WebSettings.setTextZoom(N)
        int zoom = i.getIntExtra("zoom", 100);
        s.setTextZoom(zoom);
        Log.i(TAG, "textZoom=" + zoom);

        // --ei initialScale N => WebView.setInitialScale(N)
        int initialScale = i.getIntExtra("initialScale", 0);
        if (initialScale > 0) {
            wv.setInitialScale(initialScale);
            Log.i(TAG, "initialScale=" + initialScale);
        }

        if (i.hasExtra("supportZoom")) {
            boolean v = i.getBooleanExtra("supportZoom", false);
            s.setSupportZoom(v);
            Log.i(TAG, "supportZoom=" + v);
        }

        if (i.hasExtra("zoomControls")) {
            boolean v = i.getBooleanExtra("zoomControls", false);
            s.setBuiltInZoomControls(v);
            s.setDisplayZoomControls(v);
            Log.i(TAG, "builtInZoomControls=" + v);
        }

        // --es defaultZoom FAR|MEDIUM|CLOSE (deprecated in API 19)
        String dz = i.getStringExtra("defaultZoom");
        if (dz != null) {
            try {
                Class<?> zdCls = Class.forName("android.webkit.WebSettings$ZoomDensity");
                Object val = zdCls.getMethod("valueOf", String.class).invoke(null, dz);
                Method m = WebSettings.class.getMethod("setDefaultZoom", zdCls);
                m.invoke(s, val);
                Log.i(TAG, "defaultZoom=" + dz);
            } catch (Throwable t) {
                Log.w(TAG, "defaultZoom unavailable: " + t.getMessage());
            }
        }

        String url = i.getStringExtra("url");
        if (url == null) url = "about:blank";
        wv.loadUrl(url);
        setContentView(wv);
    }
}
