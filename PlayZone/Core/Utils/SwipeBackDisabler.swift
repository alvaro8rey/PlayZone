import SwiftUI

struct SwipeBackDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            disableSwipeBack()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        disableSwipeBack()
    }

    private func disableSwipeBack() {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        var viewController = window.rootViewController
        while let presentedVC = viewController?.presentedViewController {
            viewController = presentedVC
        }

        if let navController = viewController as? UINavigationController {
            navController.interactivePopGestureRecognizer?.isEnabled = false
        }

        if let navController = viewController?.navigationController {
            navController.interactivePopGestureRecognizer?.isEnabled = false
        }

        for child in viewController?.children ?? [] {
            if let navController = child as? UINavigationController {
                navController.interactivePopGestureRecognizer?.isEnabled = false
            }
        }
    }
}
