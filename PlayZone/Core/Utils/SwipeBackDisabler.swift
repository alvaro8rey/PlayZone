import SwiftUI

/// Disables the navigation swipe-back gesture while this view is on screen.
/// Uses UIViewRepresentable so we can walk the UIKit responder chain to reach
/// the UINavigationController — more reliable than UIViewControllerRepresentable
/// whose child VC may not have navigationController set at viewWillAppear time.
struct SwipeBackDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> _DisablerView { _DisablerView() }
    func updateUIView(_: _DisablerView, context: Context) {}

    final class _DisablerView: UIView {
        private weak var nav: UINavigationController?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                self?.findAndDisable()
            }
        }

        private func findAndDisable() {
            var r: UIResponder? = self
            while let next = r?.next {
                if let found = next as? UINavigationController {
                    nav = found
                    found.interactivePopGestureRecognizer?.isEnabled = false
                    return
                }
                r = next
            }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil {
                nav?.interactivePopGestureRecognizer?.isEnabled = true
            }
        }
    }
}
