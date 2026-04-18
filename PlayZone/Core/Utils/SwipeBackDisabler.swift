import SwiftUI

/// Disables the navigation swipe-back gesture while this view is on screen.
/// Two-strategy approach: responder chain first, then full VC-tree search from
/// the key window, because SwiftUI may structure the responder chain differently
/// across iOS versions and NavigationStack vs NavigationView.
struct SwipeBackDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> _DisablerView { _DisablerView() }

    func updateUIView(_ uiView: _DisablerView, context: Context) {
        // Re-apply on every SwiftUI update to catch cases where the gesture
        // was re-enabled by the system (e.g. after a push animation).
        uiView.applyDisable()
    }

    final class _DisablerView: UIView {
        private weak var nav: UINavigationController?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // Immediate attempt + delayed attempt (layout may not be complete yet).
            applyDisable()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.applyDisable()
            }
        }

        func applyDisable() {
            guard let found = findViaResponderChain() ?? findViaWindowHierarchy() else { return }
            nav = found
            found.interactivePopGestureRecognizer?.isEnabled = false
        }

        // Walk UIKit responder chain: UIView → … → UIHostingController → UINavigationController
        private func findViaResponderChain() -> UINavigationController? {
            var r: UIResponder? = self.next
            while let responder = r {
                if let found = responder as? UINavigationController { return found }
                r = responder.next
            }
            return nil
        }

        // Fallback: BFS from the key window's root view controller
        private func findViaWindowHierarchy() -> UINavigationController? {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let root = scene.keyWindow?.rootViewController else { return nil }
            var queue = [root]
            while !queue.isEmpty {
                let vc = queue.removeFirst()
                if let nav = vc as? UINavigationController { return nav }
                queue.append(contentsOf: vc.children)
                if let presented = vc.presentedViewController { queue.append(presented) }
            }
            return nil
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil {
                nav?.interactivePopGestureRecognizer?.isEnabled = true
            }
        }
    }
}
