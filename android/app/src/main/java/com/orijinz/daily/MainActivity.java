package com.orijinz.daily;

import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    // TEMPORARY: diagnose the entspire.com blank-screen issue without needing
    // a USB cable or chrome://inspect. A few seconds after launch, probe the
    // page's own state via JS and show it as a plain on-screen alert. Remove
    // once resolved.
    private static final String DIAGNOSTIC_PROBE_JS = "(function(){return JSON.stringify({"
        + "url: location.href,"
        + "title: document.title,"
        + "htmlLen: document.documentElement.outerHTML.length,"
        + "readyState: document.readyState"
        + "});})()";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            getBridge().getWebView().evaluateJavascript(DIAGNOSTIC_PROBE_JS, value ->
                new AlertDialog.Builder(this)
                    .setTitle("Diagnostic")
                    .setMessage(value)
                    .setPositiveButton("OK", null)
                    .show()
            );
        }, 5000);
    }
}
