// LAST UPDATED: 2026-07-14 (Build 40)
import UIKit
import WebKit
import StoreKit
import AuthenticationServices

// ─── Product IDs ──────────────────────────────────────────────────────────────
// Create these in App Store Connect > your app > Monetization > Subscriptions
// One subscription group: "Orijinz Daily All Games"
//   - com.convertify.entspire2.allgames.monthly  ($5.99/mo)
//   - com.convertify.entspire2.allgames.annual   ($59.99/yr)
private let kProductMonthly = "com.convertify.entspire2.allgames.monthly"
private let kProductAnnual  = "com.convertify.entspire2.allgames.annual"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKNavigationDelegate, ASAuthorizationControllerDelegate {

    var window: UIWindow?
    private var webView: WKWebView!
    private var reloadAttempts = 0
    private var iapActive = false
    private var rootViewController: UIViewController?
    private var userEmail: String?
    private var userName: String?

    private let siteURL  = URL(string: "https://www.orijinz.com")!
    private let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1 OrijinzApp/1.0"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupWebView()
        Task { await refreshIAPStatus() }
        loadSite()
        return true
    }

    // MARK: - WebView setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Enable third-party cookies for OAuth flows (Google Sign-In, etc.)
        if #available(iOS 13.0, *) {
            config.websiteDataStore = WKWebsiteDataStore.default()
        }

        // Inject native flag before page loads so JS sees it immediately
        let injectionScript = "window.ORIJINZ_NATIVE_IOS=true;"
        let userScript = WKUserScript(source: injectionScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

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

        rootViewController = vc
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
    }

    private func loadSite() {
        reloadAttempts = 0
        webView.load(URLRequest(url: siteURL))
        scheduleStallCheck()
    }

    // MARK: - StoreKit

    private func refreshIAPStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productType == .autoRenewable {
                hasActive = true
                break
            }
        }
        iapActive = hasActive
    }

    private func purchaseSubscription(plan: String) {
        Task {
            let productID = (plan == "annual") ? kProductAnnual : kProductMonthly
            do {
                let products = try await Product.products(for: [productID])
                guard let product = products.first else {
                    js("window.orijinzIAPError&&window.orijinzIAPError('Product unavailable')")
                    return
                }
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    if case .verified(let tx) = verification {
                        await tx.finish()
                        iapActive = true
                        js("window.orijinzIAPSuccess&&window.orijinzIAPSuccess()")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                            self?.startAppleSignIn()
                        }
                    } else {
                        js("window.orijinzIAPError&&window.orijinzIAPError('Verification failed')")
                    }
                case .userCancelled:
                    js("window.orijinzIAPCancelled&&window.orijinzIAPCancelled()")
                case .pending:
                    js("window.orijinzIAPPending&&window.orijinzIAPPending()")
                @unknown default:
                    break
                }
            } catch {
                let msg = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
                js("window.orijinzIAPError&&window.orijinzIAPError(\"\(msg)\")")
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                try await AppStore.sync()
                await refreshIAPStatus()
                if iapActive {
                    js("window.orijinzIAPSuccess&&window.orijinzIAPSuccess()")
                } else {
                    js("window.orijinzIAPError&&window.orijinzIAPError('No active subscription found')")
                }
            } catch {
                js("window.orijinzIAPError&&window.orijinzIAPError('Restore failed')")
            }
        }
    }

    private func js(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    private func jsWithLog(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("❌ JS Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reloadAttempts = 0
        let active = iapActive ? "true" : "false"
        let emailStr = userEmail.map { "'\($0)'" } ?? "null"
        let nameStr = userName.map { "'\($0)'" } ?? "null"
        print("📄 Page loaded: \(webView.url?.absoluteString ?? "unknown")")
        js("window.ORIJINZ_NATIVE_IOS=true;window.ORIJINZ_IAP_ACTIVE=\(active);window.ORIJINZ_USER_EMAIL=\(emailStr);window.ORIJINZ_USER_NAME=\(nameStr);window.postMessage({type:'nativeIOSReady',iapActive:\(active),email:\(emailStr),name:\(nameStr)},'*');")
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
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }

        print("🔗 Navigation: \(url.absoluteString)")

        if url.scheme == "orijinz" {
            print("✅ Intercepted orijinz:// scheme: \(url.absoluteString)")
            handleScheme(url)
            decisionHandler(.cancel)
            return
        }

        // Intercept subscribe requests and load iOS-specific page
        // But block redirect if user is subscribed (game page shouldn't redirect subscribed users)
        if (url.path.contains("/subscribe") || url.path == "/subscribe"),
           let host = url.host,
           (host.contains("orijinz") || host.contains("entspire")) {
            if iapActive {
                // Subscribed user—block this redirect
                js("window.history.back()")
                decisionHandler(.cancel)
                return
            }
            // Not subscribed—show iOS subscribe page
            let iosSubscribeURL = URL(string: "https://orijinz.github.io/website/orijinz-subscribe-ios.html")!
            webView.load(URLRequest(url: iosSubscribeURL))
            decisionHandler(.cancel)
            return
        }

        // Intercept game URLs and load from GitHub wrapper (injects flag before navigating)
        // But don't re-intercept if wrapper already tried (has fromWrapper=1 parameter)
        let gameIds = ["odwordsandphrases", "od70s-songs", "odcovers", "odmovies", "odslogans", "odquotes", "odbooks"]
        let isGameURL = gameIds.contains { url.path.contains($0) }
        let hasFromWrapperParam = url.query?.contains("fromWrapper=1") ?? false
        if isGameURL && !hasFromWrapperParam, let host = url.host, (host.contains("entspire")) {
            var gameId = "odwordsandphrases"
            for id in gameIds {
                if url.path.contains(id) {
                    gameId = id
                    break
                }
            }
            let iosGameURL = URL(string: "https://orijinz.github.io/website/orijinz-game-ios.html?game=\(gameId)")!
            webView.load(URLRequest(url: iosGameURL))
            decisionHandler(.cancel)
            return
        }

        if navigationAction.navigationType == .linkActivated,
           let host = url.host,
           !host.contains("orijinz.com"),
           !host.contains("entspire.com"),
           !host.contains("wix.com"),
           !host.contains("wixstatic.com"),
           !host.contains("wixapps.net"),
           !host.contains("parastorage.com"),
           !host.contains("stripe.com"),
           !host.contains("github.com") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - orijinz:// scheme

    private func handleScheme(_ url: URL) {
        guard let action = url.host else { return }
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let param = { (name: String) -> String? in q?.queryItems?.first { $0.name == name }?.value }
        switch action {
        case "subscribe": purchaseSubscription(plan: param("plan") ?? "monthly")
        case "restore":   restorePurchases()
        default:          break
        }
    }

    // MARK: - Stall watchdog

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

    // MARK: - UIApplicationDelegate

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "orijinz" {
            handleScheme(url)
            return true
        }
        return false
    }
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool { true }

    // MARK: - Apple Sign-In

    private func startAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let email = appleIDCredential.email ?? "user@orijinz.app"
        let fullName = appleIDCredential.fullName
        let givenName = fullName?.givenName ?? "User"
        userEmail = email
        userName = givenName
        DispatchQueue.main.async { [weak self] in
            self?.js("window.orijinzAppleSignInSuccess&&window.orijinzAppleSignInSuccess({email:'\(email)',name:'\(givenName)'})")
            self?.createWixAccount(email: email, name: givenName)
        }
    }

    private func createWixAccount(email: String, name: String) {
        let url = URL(string: "https://www.entspire.com/_functions/createIosAccount")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["email": email, "name": name]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Account creation error: \(error.localizedDescription)")
            } else {
                print("Account created successfully for \(email)")
            }
        }.resume()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let msg = (error as NSError).localizedDescription.replacingOccurrences(of: "\"", with: "'")
        js("window.orijinzAppleSignInError&&window.orijinzAppleSignInError('\(msg)')")
    }

}
