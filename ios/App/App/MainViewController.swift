import UIKit
import Capacitor

// TEMPORARY: diagnose the entspire.com blank-screen issue without needing a
// Mac/Safari Web Inspector. A few seconds after launch, probe the page's own
// state via JS and show it as a plain on-screen alert. Remove once resolved.
class MainViewController: CAPBridgeViewController {
    private static let diagnosticProbeJS = """
    (function(){return JSON.stringify({
        url: location.href,
        title: document.title,
        htmlLen: document.documentElement.outerHTML.length,
        readyState: document.readyState
    });})()
    """

    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showDiagnostic()
        }
    }

    private func showDiagnostic() {
        webView?.evaluateJavaScript(Self.diagnosticProbeJS) { [weak self] result, error in
            let message = error.map { "JS eval error: \($0.localizedDescription)" }
                ?? (result as? String) ?? "no result"
            let alert = UIAlertController(title: "Diagnostic", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}
