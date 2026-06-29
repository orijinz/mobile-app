import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    private var didShowDiagnosticOverlay = false

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        guard !didShowDiagnosticOverlay else { return }
        didShowDiagnosticOverlay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showDiagnosticOverlay()
        }
    }

    // TEMPORARY: diagnose the entspire.com blank-screen issue. Draws straight
    // onto the window instead of presenting an alert, so it can't be
    // silently swallowed by view-controller presentation timing, and reports
    // even if the WebView reference itself is unexpectedly missing. Remove
    // once resolved.
    private func showDiagnosticOverlay() {
        guard let window = window else { return }

        let label = UILabel(frame: CGRect(x: 8, y: 50, width: window.bounds.width - 16, height: window.bounds.height - 100))
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        label.text = "DIAG: starting..."
        window.addSubview(label)

        guard let bridgeVC = window.rootViewController as? CAPBridgeViewController,
              let webView = bridgeVC.webView else {
            label.text = "DIAG: no CAPBridgeViewController/webView found"
            return
        }

        // Synchronous info first -- doesn't depend on JS evaluation
        // completing, so it shows even if the page's JS engine is stuck.
        let syncInfo = "DIAG sync: url=\(webView.url?.absoluteString ?? "nil") "
            + "isLoading=\(webView.isLoading) progress=\(webView.estimatedProgress)"
        label.text = syncInfo

        let probe = """
        (function(){
            var resources = performance.getEntriesByType('resource');
            var pending = resources.filter(function(r){ return r.responseEnd === 0; }).map(function(r){ return r.name; });
            var body = document.body;
            var style = body ? getComputedStyle(body) : null;
            return JSON.stringify({
                url: location.href,
                title: document.title,
                htmlLen: document.documentElement.outerHTML.length,
                readyState: document.readyState,
                bodyDisplay: style ? style.display : 'no body',
                bodyVisibility: style ? style.visibility : 'no body',
                bodyOpacity: style ? style.opacity : 'no body',
                totalResources: resources.length,
                pendingResources: pending.slice(0, 8)
            });
        })()
        """
        webView.evaluateJavaScript(probe) { result, error in
            let jsInfo: String
            if let error = error {
                jsInfo = "JS error: \(error.localizedDescription)"
            } else {
                jsInfo = "JS: \((result as? String) ?? "no result")"
            }
            label.text = syncInfo + "\n" + jsInfo
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
