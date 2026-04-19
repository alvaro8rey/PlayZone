import SwiftUI

struct SwipeBackDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.attachIfNeeded(to: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var pan: UIPanGestureRecognizer?
        private weak var attachedView: UIView?

        func attachIfNeeded(to view: UIView) {
            guard pan == nil else { return }
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                guard let navView = self.findNavView(from: view) else { return }
                let p = UIPanGestureRecognizer(target: self, action: #selector(self.handle))
                p.delegate = self
                navView.addGestureRecognizer(p)
                self.pan = p
                self.attachedView = navView
            }
        }

        func detach() {
            if let p = pan, let v = attachedView { v.removeGestureRecognizer(p) }
            pan = nil
            attachedView = nil
        }

        @objc private func handle(_ gr: UIPanGestureRecognizer) {
            // No hace nada - solo bloquea el gesto de navegación
        }

        // El gesto de navegación espera a que el nuestro falle.
        // Como el nuestro siempre falla, la navegación nunca se ejecuta.
        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            return other is UIScreenEdgePanGestureRecognizer
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return false
        }

        private func findNavView(from view: UIView) -> UIView? {
            var r: UIResponder? = view.next
            while let resp = r {
                if let nav = resp as? UINavigationController { return nav.view }
                r = resp.next
            }
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let root = scene.keyWindow?.rootViewController else { return nil }
            var queue = [root]
            while !queue.isEmpty {
                let vc = queue.removeFirst()
                if let nav = vc as? UINavigationController { return nav.view }
                queue.append(contentsOf: vc.children)
                if let p = vc.presentedViewController { queue.append(p) }
            }
            return nil
        }
    }
}
