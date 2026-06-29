package com.orijinz.daily;

import android.os.Bundle;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // TEMPORARY: force-enable WebView remote debugging even in release
        // builds, so chrome://inspect can show console errors while we
        // diagnose the entspire.com blank-screen issue. Remove once resolved.
        WebView.setWebContentsDebuggingEnabled(true);
    }
}
