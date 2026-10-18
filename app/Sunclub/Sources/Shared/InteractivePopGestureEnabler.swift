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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enableInteractivePopGestureIfNeeded()
    }

    func enableInteractivePopGestureIfNeeded() {
        guard let navigationController else { return }

        if #available(iOS 27.1, *) {
            // An empty navigation title can leave Duo's vertical native Back
            // control unnamed. The preceding item's title supplies its label
            // without replacing UIKit's back action or transition delegate.
            for controller in navigationController.viewControllers.dropLast() {
                if controller.navigationItem.backBarButtonItem == nil {
                    let backItem = UIBarButtonItem(
                        title: String(localized: "Back"), style: .plain, target: nil, action: nil
                    )
                    backItem.accessibilityLabel = String(localized: "Back")
                    controller.navigationItem.backBarButtonItem = backItem
                }
            }
        }

        if #available(iOS 26.0, *) {
            // Keep UIKit's native back action, accessibility, and transition delegate.
            return
        }

        let recognizer = navigationController.interactivePopGestureRecognizer
        recognizer?.isEnabled = navigationController.viewControllers.count > 1
        recognizer?.delegate = nil
    }
}
