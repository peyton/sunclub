import SwiftUI
import UIKit

struct TimelineScrubCalculator: Equatable {
    static let defaultDayStride: CGFloat = 68

    let visibleDays: [Date]
    let calendar: Calendar
    let dayStride: CGFloat

    init(
        visibleDays: [Date],
        calendar: Calendar = .current,
        dayStride: CGFloat = Self.defaultDayStride
    ) {
        self.visibleDays = visibleDays.map { calendar.startOfDay(for: $0) }
        self.calendar = calendar
        self.dayStride = dayStride
    }

    func index(for day: Date) -> Int? {
        let normalized = calendar.startOfDay(for: day)
        return visibleDays.firstIndex(of: normalized)
    }

    func selectedDay(startDay: Date, translation: CGFloat) -> Date? {
        guard let startIndex = index(for: startDay) else {
            return nil
        }
        return visibleDays[selectedIndex(startIndex: startIndex, translation: translation)]
    }

    func selectedIndex(startIndex: Int, translation: CGFloat) -> Int {
        guard !visibleDays.isEmpty else {
            return 0
        }
        let projected = CGFloat(startIndex) - (translation / dayStride)
        let rounded = Int(projected.rounded())
        return min(max(rounded, visibleDays.startIndex), visibleDays.index(before: visibleDays.endIndex))
    }

    func scrubOffset(startIndex: Int, translation: CGFloat) -> CGFloat {
        guard !visibleDays.isEmpty else {
            return 0
        }
        let minIndex = CGFloat(visibleDays.startIndex)
        let maxIndex = CGFloat(visibleDays.index(before: visibleDays.endIndex))
        let projected = CGFloat(startIndex) - (translation / dayStride)
        let bounded = min(max(projected, minIndex), maxIndex)
        let boundedTranslation = (CGFloat(startIndex) - bounded) * dayStride
        let overflow = translation - boundedTranslation

        guard overflow != 0 else {
            return translation
        }
        return boundedTranslation + Self.rubberBand(overflow, dimension: dayStride * 2.5)
    }

    static func rubberBand(_ overflow: CGFloat, dimension: CGFloat) -> CGFloat {
        guard overflow != 0, dimension > 0 else {
            return 0
        }
        let magnitude = abs(overflow)
        let banded = (dimension * magnitude) / (dimension + magnitude)
        return overflow < 0 ? -banded : banded
    }
}

enum TimelineScrubAxis: Equatable {
    case horizontal
    case vertical
}

struct TimelineScrubGestureClassifier: Equatable {
    let minimumDistance: CGFloat
    let horizontalDominance: CGFloat

    init(minimumDistance: CGFloat = 18, horizontalDominance: CGFloat = 1.35) {
        self.minimumDistance = minimumDistance
        self.horizontalDominance = horizontalDominance
    }

    func axis(current: TimelineScrubAxis?, translation: CGSize) -> TimelineScrubAxis? {
        if let current {
            return current
        }

        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)
        guard max(horizontal, vertical) >= minimumDistance else {
            return nil
        }

        if horizontal >= vertical * horizontalDominance {
            return .horizontal
        }
        if vertical >= horizontal {
            return .vertical
        }
        return nil
    }
}

struct TimelineBodyScrubGestureLayer: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, CGSize) -> Void
    let onTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded, onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isAccessibilityElement = false

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        if onTap != nil {
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(onChanged: onChanged, onEnded: onEnded, onTap: onTap)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var onChanged: (CGSize) -> Void
        private var onEnded: (CGSize, CGSize) -> Void
        private var onTap: (() -> Void)?

        init(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize, CGSize) -> Void,
            onTap: (() -> Void)?
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onTap = onTap
        }

        func update(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize, CGSize) -> Void,
            onTap: (() -> Void)?
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onTap = onTap
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer is UIPanGestureRecognizer
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else {
                return
            }
            let translation = recognizer.translation(in: view)
            let translationSize = CGSize(width: translation.x, height: translation.y)

            switch recognizer.state {
            case .began, .changed:
                onChanged(translationSize)
            case .ended:
                onEnded(translationSize, translationSize)
            case .cancelled, .failed:
                onEnded(translationSize, translationSize)
            default:
                break
            }
        }

        @objc func handleTap() {
            onTap?()
        }
    }
}
