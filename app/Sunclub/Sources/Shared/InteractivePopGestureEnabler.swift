import SwiftUI
import UIKit

struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopGestureViewController {
        InteractivePopGestureViewController()
    }

    func updateUIViewController(_ uiViewController: InteractivePopGestureViewController, context: Context) {
        uiViewController.enableInteractivePopGestureIfNeeded()
    }
}

extension View {
    func interactivePopGestureEnabled() -> some View {
        background {
            InteractivePopGestureEnabler()
        }
    }
}

@MainActor
final class InteractivePopGestureViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableInteractivePopGestureIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableInteractivePopGestureIfNeeded()
    }

    func enableInteractivePopGestureIfNeeded() {
        guard let navigationController else { return }

        let recognizer = navigationController.interactivePopGestureRecognizer
        recognizer?.isEnabled = navigationController.viewControllers.count > 1
        recognizer?.delegate = nil
    }
}
