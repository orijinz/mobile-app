// LAST UPDATED: 2026-07-08 07:42
import UIKit
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKNavigationDelegate {

    var window: UIWindow?
    private var webView: WKWebView!
    private var reloadAttempts = 0

    private let siteURL = URL(string: "https://www.entspire.com")!

    // Matches a real iPhone Safari UA so Wix/Cloudflare don't fingerprint the WebView.
    private let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = mobileUA
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        let vc = UIViewController()
        vc.view.backgroundColor = .white
        webView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
        ])

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        loadSite()
        return true
    }

    private func loadSite() {
        reloadAttempts = 0
        webView.load(URLRequest(url: siteURL))
        scheduleStallCheck()
    }

    private func scheduleStallCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.checkForStall()
        }
    }

    private func checkForStall() {
        guard reloadAttempts < 3 else { return }
        if webView.isLoading {
            reloadAttempts += 1
            webView.reload()
            scheduleStallCheck()
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reloadAttempts = 0
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard reloadAttempts < 3 else { return }
        reloadAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.webView.reload()
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // Phase 2: orijinz:// scheme triggers native StoreKit IAP
        if url.scheme == "orijinz" {
            decisionHandler(.cancel)
            return
        }
        // User-tapped links to unrelated domains open in Safari, not the WebView
        if navigationAction.navigationType == .linkActivated,
           let host = url.host,
           !host.contains("entspire.com"),
           !host.contains("wix.com"),
           !host.contains("wixstatic.com"),
           !host.contains("wixapps.net"),
           !host.contains("parastorage.com"),
           !host.contains("stripe.com") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - UIApplicationDelegate stubs

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool { true }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool { true }
}
