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
    // TEMPORARY diagnostic: blank-screen test build, isolating whether ANY
    // remote URL renders before suspecting something entspire.com-specific.
    // Revert to entspire.com once resolved.
    url: 'https://example.com',
    allowNavigation: [
      'entspire.com',
      '*.entspire.com',
      'checkout.stripe.com',
      'js.stripe.com',
    ],
  },
};

export default config;
