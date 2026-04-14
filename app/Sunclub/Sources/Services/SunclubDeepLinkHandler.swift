import Foundation

enum SunclubDeepLinkHandler {
    @discardableResult
    @MainActor
    static func handle(
        url: URL,
        appState: AppState,
        router: AppRouter,
        openExternalURL: ((URL) -> Void)? = nil
    ) -> Bool {
        guard let deepLink = SunclubDeepLink(url: url) else {
            return false
        }

        return handle(deepLink, appState: appState, router: router, openExternalURL: openExternalURL)
    }

    @discardableResult
    @MainActor
    static func handle(
        _ deepLink: SunclubDeepLink,
        appState: AppState,
        router: AppRouter,
        openExternalURL: ((URL) -> Void)? = nil
    ) -> Bool {
        switch deepLink {
        case .widgetLogToday:
            return handleWidgetLogToday(appState: appState, router: router)
        case let .widgetRoute(route):
            return openAfterOnboarding(route.appRoute, appState: appState, router: router)
        case let .accountabilityInvite(code):
            return handleAccountabilityInvite(code, appState: appState, router: router)
        case let .accountabilityPoke(friendID):
            return handleAccountabilityPoke(friendID, appState: appState, router: router)
        case let .automation(request):
            return handleAutomation(request, appState: appState, router: router, openExternalURL: openExternalURL)
        }
    }

    @MainActor
    private static func handleWidgetLogToday(appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return true
        }

        appState.recordVerificationSuccess(method: .quickLog)
        if let presentation = appState.verificationSuccessPresentation {
            appState.verificationSuccessPresentation = VerificationSuccessPresentation(
                streak: presentation.streak,
                isPersonalBest: presentation.isPersonalBest,
                canAddDetails: true
            )
        }
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        router.open(.verifySuccess)
        return true
    }

    @MainActor
    private static func handleAccountabilityInvite(_ code: String, appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            try? appState.queuePendingAccountabilityInviteCode(code)
            router.goToWelcome()
            return true
        }

        try? appState.importAccountabilityInviteCode(code)
        router.open(.friends)
        return true
    }

    @MainActor
    private static func handleAccountabilityPoke(_ friendID: UUID?, appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return true
        }

        if let friendID {
            appState.sendDirectPoke(to: friendID)
        }
        router.open(.friends)
        return true
    }

    @MainActor
    private static func openAfterOnboarding(_ route: AppRoute, appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return true
        }

        router.open(route)
        return true
    }

    @MainActor
    private static func handleAutomation(
        _ request: SunclubAutomationRequest,
        appState: AppState,
        router: AppRouter,
        openExternalURL: ((URL) -> Void)?
    ) -> Bool {
        do {
            let result = try appState.performAutomationAction(request.action, invocation: .url)
            if case let .open(route) = request.action {
                _ = openAfterOnboarding(route.appRoute, appState: appState, router: router)
            } else if request.callback == nil {
                routeAfterForegroundAutomation(request.action, result: result, appState: appState, router: router)
            }
            openSuccessCallbackIfNeeded(request.callback, result: result, appState: appState, openExternalURL: openExternalURL)
        } catch let error as SunclubAutomationError {
            openErrorCallbackIfNeeded(
                request.callback,
                action: request.action.identifier,
                error: error,
                appState: appState,
                openExternalURL: openExternalURL
            )
            if request.callback == nil {
                routeAfterAutomationError(error, request.action, appState: appState, router: router)
            }
        } catch {
            let automationError = SunclubAutomationError.unavailable(error.localizedDescription)
            openErrorCallbackIfNeeded(
                request.callback,
                action: request.action.identifier,
                error: automationError,
                appState: appState,
                openExternalURL: openExternalURL
            )
            if request.callback == nil {
                routeAfterAutomationError(automationError, request.action, appState: appState, router: router)
            }
        }
        return true
    }

    @MainActor
    private static func routeAfterForegroundAutomation(
        _ action: SunclubAutomationAction,
        result: SunclubAutomationResult,
        appState: AppState,
        router: AppRouter
    ) {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return
        }

        switch action {
        case .logToday:
            appState.verificationSuccessPresentation = VerificationSuccessPresentation(
                streak: result.currentStreak ?? appState.currentStreak,
                canAddDetails: true
            )
            router.open(.verifySuccess)
        case .saveLog:
            router.open(.history)
        case .reapply:
            router.goHome()
        case .setReminder, .setReapply, .setToggle:
            router.open(.automation)
        case .importFriend, .pokeFriend:
            router.open(.friends)
        case .status, .timeSinceLastApplication:
            router.goHome()
        case .open, .exportBackup, .createSkinHealthReport, .createStreakCard:
            break
        }
    }

    @MainActor
    private static func routeAfterAutomationError(
        _ error: SunclubAutomationError,
        _ action: SunclubAutomationAction,
        appState: AppState,
        router: AppRouter
    ) {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return
        }

        switch action {
        case .reapply:
            router.open(.manualLog)
        case .setReminder, .setReapply, .setToggle, .status, .timeSinceLastApplication:
            router.open(.automation)
        case .importFriend, .pokeFriend:
            router.open(.friends)
        case .open:
            if error == .urlOpenActionsDisabled {
                router.open(.automation)
            }
        case .logToday, .saveLog:
            router.open(.manualLog)
        case .exportBackup, .createSkinHealthReport, .createStreakCard:
            router.open(.skinHealthReport)
        }
    }

    @MainActor
    private static func openSuccessCallbackIfNeeded(
        _ callback: SunclubXCallback?,
        result: SunclubAutomationResult,
        appState: AppState,
        openExternalURL: ((URL) -> Void)?
    ) {
        guard let successURL = callback?.successURL else {
            return
        }
        let callbackURL = SunclubXCallbackResponse.successURL(
            baseURL: successURL,
            result: result,
            includesDetails: appState.automationPreferences.callbackResultDetailsEnabled
        )
        openExternalURL?(callbackURL)
    }

    @MainActor
    private static func openErrorCallbackIfNeeded(
        _ callback: SunclubXCallback?,
        action: String,
        error: SunclubAutomationError,
        appState: AppState,
        openExternalURL: ((URL) -> Void)?
    ) {
        guard let errorURL = callback?.errorURL else {
            return
        }
        let callbackURL = SunclubXCallbackResponse.errorURL(
            baseURL: errorURL,
            action: action,
            error: error,
            includesDetails: appState.automationPreferences.callbackResultDetailsEnabled
        )
        openExternalURL?(callbackURL)
    }
}
