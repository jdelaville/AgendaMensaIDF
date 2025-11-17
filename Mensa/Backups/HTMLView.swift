import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
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
                    word-wrap: break-word;        /* Retour à la ligne pour mots longs */
                    overflow-wrap: break-word;    /* Support large mots / URLs */
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
                    word-break: break-word;       /* Retour à la ligne sur URL longues */
                }
                strong {
                    word-break: break-word;       /* Evite que les titres dépassent */
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
