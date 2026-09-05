import SwiftUI

/// Compatibility entrypoint for manual-log URLs and existing foreground routes.
struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @State private var resolvedContext: AppLogContext?

    init(context: AppLogContext? = nil) {
        _resolvedContext = State(initialValue: context)
    }

    var body: some View {
        Group {
            if let resolvedContext {
                HistoryRecordEditorView(
                    day: resolvedContext.date,
                    existingRecord: appState.record(for: resolvedContext.date),
                    route: .manualLog,
                    targetContext: resolvedContext,
                    prefill: appState.manualLogPrefill,
                    accessibilityPrefix: "manualLog"
                )
            } else {
                Color.clear
                    .task {
                        resolvedContext = appState.currentLogContext(
                            for: appState.referenceDate,
                            source: .manualLog
                        )
                    }
            }
        }
    }
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
