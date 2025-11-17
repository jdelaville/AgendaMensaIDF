import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: makeConfig())
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let safeHTML = htmlContent
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        let htmlString = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    font-family: -apple-system;
                    color: #333;
                    font-size: 16px;
                    padding: 0;
                    margin: 0;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 8px 0;
                }
                p {
                    margin-bottom: 10px;
                }
                a {
                    color: #007AFF;
                    text-decoration: none;
                    word-break: break-word;
                }
                strong {
                    word-break: break-word;
                }
            </style>
        </head>
        <body>
            \(safeHTML)
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func makeConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        // ⚡ Optimisations pour réduire le temps GPU
        config.suppressesIncrementalRendering = true
        config.allowsInlineMediaPlayback = true
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false
        config.defaultWebpagePreferences = preferences
        config.websiteDataStore = .default()
        return config
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLView
        init(_ parent: HTMLView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { (height, error) in
                if let h = height as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = h
                    }
                }
            }
        }
    }
}
