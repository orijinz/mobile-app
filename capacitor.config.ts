import type { CapacitorConfig } from '@capacitor/cli';

// Phase 1: the app is just a reliable webview shell pointed straight at the
// live site. No bridge/postMessage logic yet — that's added in Phase 2 along
// with RevenueCat IAP. allowNavigation covers Stripe's checkout domains so
// the existing web subscribe flow keeps working unmodified inside the app.
// Note: appId here only reflects iOS (com.convertify.entspire2). Android's
// real applicationId is com.app.entspirellc, set directly in
// android/app/build.gradle since the two platforms' existing App
// Store/Play Store listings use different identifiers.
const config: CapacitorConfig = {
  appId: 'com.convertify.entspire2',
  appName: 'Orijinz Daily',
  webDir: 'www',
  server: {
    url: 'https://www.entspire.com',
    allowNavigation: [
      'entspire.com',
      '*.entspire.com',
      'checkout.stripe.com',
      'js.stripe.com',
    ],
  },
  // The site occasionally stalled mid-load only inside the embedded
  // WebView, never in regular Safari/Chrome. Capacitor's bridge exposes
  // window.webkit.messageHandlers (iOS) to page JS, which real browsers
  // never do -- some sites' browser-detection/bot-defense scripts branch
  // differently when they see that. Presenting a normal mobile-browser
  // user agent avoids that branch.
  ios: {
    overrideUserAgent:
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
  },
  android: {
    overrideUserAgent:
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  },
};

export default config;
