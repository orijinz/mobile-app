package com.orijinz.daily;

import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;
import android.widget.TextView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    // TEMPORARY: diagnose the entspire.com blank-screen issue without needing
    // a USB cable or chrome://inspect. A few seconds after launch, draw a
    // text overlay directly on screen (not a dialog, so it can't be silently
    // swallowed by presentation timing) showing the page's own JS-reported
    // state. Remove once resolved.
    private static final String DIAGNOSTIC_PROBE_JS = "(function(){"
        + "var resources = performance.getEntriesByType('resource');"
        + "var pending = resources.filter(function(r){ return r.responseEnd === 0; }).map(function(r){ return r.name; });"
        + "var body = document.body;"
        + "var style = body ? getComputedStyle(body) : null;"
        + "return JSON.stringify({"
        + "url: location.href,"
        + "title: document.title,"
        + "htmlLen: document.documentElement.outerHTML.length,"
        + "readyState: document.readyState,"
        + "bodyDisplay: style ? style.display : 'no body',"
        + "bodyVisibility: style ? style.visibility : 'no body',"
        + "bodyOpacity: style ? style.opacity : 'no body',"
        + "totalResources: resources.length,"
        + "pendingResources: pending.slice(0, 8)"
        + "});"
        + "})()";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        new Handler(Looper.getMainLooper()).postDelayed(this::showDiagnosticOverlay, 5000);
    }

    private void showDiagnosticOverlay() {
        TextView label = new TextView(this);
        label.setTextColor(Color.WHITE);
        label.setBackgroundColor(Color.argb(220, 0, 0, 0));
        label.setPadding(16, 16, 16, 16);
        label.setText("DIAG: starting...");
        addContentView(label, new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        if (getBridge() == null || getBridge().getWebView() == null) {
            label.setText("DIAG: no bridge/webView found");
            return;
        }

        android.webkit.WebView webView = getBridge().getWebView();
        // Synchronous info first -- doesn't depend on JS evaluation
        // completing, so it shows even if the page's JS engine is stuck.
        String syncInfo = "DIAG sync: url=" + webView.getUrl()
            + " progress=" + webView.getProgress();
        label.setText(syncInfo);

        webView.evaluateJavascript(DIAGNOSTIC_PROBE_JS, value ->
            label.setText(syncInfo + "\nJS: " + value)
        );
    }
}
