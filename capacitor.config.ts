import type { CapacitorConfig } from '@capacitor/cli';

// Phase 1: the app is just a reliable webview shell pointed straight at the
// live site. No bridge/postMessage logic yet — that's added in Phase 2 along
// with RevenueCat IAP. allowNavigation covers Stripe's checkout domains so
// the existing web subscribe flow keeps working unmodified inside the app.
const config: CapacitorConfig = {
  appId: 'com.orijinz.daily',
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
};

export default config;
