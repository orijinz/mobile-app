import UIKit
import Capacitor
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKScriptMessageHandler {

    var window: UIWindow?
    private var diagLogView: UITextView?
    private var diagLogLines: [String] = []

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

    private var didSetUpDiagnostics = false

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        guard !didSetUpDiagnostics else { return }
        didSetUpDiagnostics = true
        setUpDiagnosticOverlay()
    }

    // TEMPORARY: diagnose the entspire.com blank-screen issue. A one-shot
    // probe after a delay couldn't see anything once the page's JS hung --
    // the query just queues forever behind whatever's stuck, same as
    // everything else. Instead, inject a script at document-start that logs
    // fetches/errors/heartbeats out to native *as they happen*, before any
    // freeze, then reload so the instrumented script is active for this
    // load. Draws straight onto the window (not a dialog) so it can't be
    // silently swallowed by presentation timing. Remove once resolved.
    private func setUpDiagnosticOverlay() {
        guard let window = window else { return }

        let textView = UITextView(frame: CGRect(x: 8, y: 50, width: window.bounds.width - 16, height: window.bounds.height - 100))
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 11)
        textView.textColor = .white
        textView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        textView.text = "DIAG: setting up..."
        window.addSubview(textView)
        diagLogView = textView

        guard let bridgeVC = window.rootViewController as? CAPBridgeViewController,
              let webView = bridgeVC.webView else {
            textView.text = "DIAG: no CAPBridgeViewController/webView found"
            return
        }

        let script = """
        (function() {
            function log(msg) {
                try { window.webkit.messageHandlers.diagLog.postMessage(String(msg)); } catch (e) {}
            }
            window.addEventListener('error', function(e) {
                log('ERROR: ' + e.message + ' @ ' + e.filename + ':' + e.lineno);
            });
            window.addEventListener('unhandledrejection', function(e) {
                var reason = e.reason && e.reason.message ? e.reason.message : e.reason;
                log('UNHANDLED REJECTION: ' + reason);
            });
            var origFetch = window.fetch;
            if (origFetch) {
                window.fetch = function(input) {
                    var u = (typeof input === 'string') ? input : (input && input.url) || 'unknown';
                    log('FETCH START: ' + u);
                    return origFetch.apply(this, arguments).then(function(r) {
                        log('FETCH DONE (' + r.status + '): ' + u);
                        return r;
                    }).catch(function(err) {
                        log('FETCH FAIL: ' + u + ' - ' + err);
                        throw err;
                    });
                };
            }
            var start = Date.now();
            setInterval(function() {
                log('heartbeat t=' + (Date.now() - start) + 'ms readyState=' + document.readyState);
            }, 1000);
            log('instrumentation installed');
        })();
        """
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(userScript)
        webView.configuration.userContentController.add(self, name: "diagLog")

        appendDiagLog("DIAG: instrumentation installed, reloading...")
        webView.reload()
    }

    private func appendDiagLog(_ line: String) {
        diagLogLines.append(line)
        if diagLogLines.count > 40 {
            diagLogLines.removeFirst(diagLogLines.count - 40)
        }
        diagLogView?.text = diagLogLines.joined(separator: "\n")
        if let textView = diagLogView {
            textView.scrollRangeToVisible(NSRange(location: textView.text.count, length: 0))
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        appendDiagLog("\(message.body)")
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
