package com.orijinz.daily;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    // The page occasionally stalls mid-load only inside the embedded
    // WebView, never in regular Chrome. Root cause wasn't pinned down after
    // extensive on-device diagnosis. Reload automatically if the page
    // hasn't finished loading after 10s, capped at 2 retries, so a stall
    // self-recovers instead of leaving a permanent blank screen.
    private int reloadAttempts = 0;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        scheduleStallCheck();
    }

    private void scheduleStallCheck() {
        new Handler(Looper.getMainLooper()).postDelayed(this::checkForStall, 10000);
    }

    private void checkForStall() {
        if (getBridge() == null || getBridge().getWebView() == null) {
            return;
        }
        android.webkit.WebView webView = getBridge().getWebView();
        if (webView.getProgress() < 100 && reloadAttempts < 2) {
            reloadAttempts++;
            webView.reload();
            scheduleStallCheck();
        }
    }
}
