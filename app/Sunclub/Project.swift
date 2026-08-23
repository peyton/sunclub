import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")
let defaultWatchDeploymentTarget: DeploymentTargets = .watchOS("11.0")
let signingTeam = Environment.teamId.getString(default: "3VDQ4656LX")
let marketingVersion = Environment.sunclubMarketingVersion.getString(default: "1.0.0")
let buildNumber = Environment.sunclubBuildNumber.getString(default: "1")
let apsEnvironment = Environment.sunclubApsEnvironment.getString(default: "development")
let cloudKitEnvironment = apsEnvironment == "production" ? "Production" : "Development"
let currentProjectVersion = {
    let digits = buildNumber.filter(\.isNumber)
    return digits.isEmpty ? "1" : digits
}()

struct SunclubFlavor {
    let appTargetName: String
    let widgetTargetName: String
    let watchTargetName: String
    let watchWidgetTargetName: String
    let bundleID: String
    let widgetBundleID: String
    let watchBundleID: String
    let watchWidgetBundleID: String
    let appGroupID: String
    let cloudKitContainerIdentifier: String
    let displayName: String
    let urlScheme: String
    let publicAccountabilityTransportEnabled: Bool

    var appPathName: String { appTargetName }
}

let productionFlavor = SunclubFlavor(
    appTargetName: "Sunclub",
    widgetTargetName: "SunclubWidgetsExtension",
    watchTargetName: "SunclubWatch",
    watchWidgetTargetName: "SunclubWatchWidgetsExtension",
    bundleID: "app.peyton.sunclub",
    widgetBundleID: "app.peyton.sunclub.widgets",
    watchBundleID: "app.peyton.sunclub.watch",
    watchWidgetBundleID: "app.peyton.sunclub.watch.widgets",
    appGroupID: "group.app.peyton.sunclub",
    cloudKitContainerIdentifier: "iCloud.app.peyton.sunclub",
    displayName: "Sunclub",
    urlScheme: "sunclub",
    publicAccountabilityTransportEnabled: false
)

let developmentFlavor = SunclubFlavor(
    appTargetName: "SunclubDev",
    widgetTargetName: "SunclubDevWidgetsExtension",
    watchTargetName: "SunclubDevWatch",
    watchWidgetTargetName: "SunclubDevWatchWidgetsExtension",
    bundleID: "app.peyton.sunclub.dev",
    widgetBundleID: "app.peyton.sunclub.dev.widgets",
    watchBundleID: "app.peyton.sunclub.dev.watch",
    watchWidgetBundleID: "app.peyton.sunclub.dev.watch.widgets",
    appGroupID: "group.app.peyton.sunclub.dev",
    cloudKitContainerIdentifier: "iCloud.app.peyton.sunclub.dev",
    displayName: "Sunclub Dev",
    urlScheme: "sunclub-dev",
    publicAccountabilityTransportEnabled: false
)

func flavorBuildSettings(_ flavor: SunclubFlavor) -> SettingsDictionary {
    [
        "SUNCLUB_APP_GROUP_ID": .string(flavor.appGroupID),
        "SUNCLUB_APS_ENVIRONMENT": .string(apsEnvironment),
        "SUNCLUB_ICLOUD_CONTAINER": .string(flavor.cloudKitContainerIdentifier),
        "SUNCLUB_ICLOUD_ENVIRONMENT": .string(cloudKitEnvironment),
        "SUNCLUB_URL_SCHEME": .string(flavor.urlScheme),
        "SUNCLUB_DISPLAY_NAME": .string(flavor.displayName),
        "SUNCLUB_PUBLIC_ACCOUNTABILITY_TRANSPORT_ENABLED": .string(
            flavor.publicAccountabilityTransportEnabled ? "YES" : "NO"
        )
    ]
}

func targetSettings(for flavor: SunclubFlavor, supportedPlatforms: String? = nil) -> Settings {
    var base = SettingsDictionary()
        .automaticCodeSigning(devTeam: signingTeam)

    for (key, value) in flavorBuildSettings(flavor) {
        base[key] = value
    }
    if let supportedPlatforms {
        base["SUPPORTED_PLATFORMS"] = .string(supportedPlatforms)
    }
    base["SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphoneos27.*]"] =
        .string("$(inherited) SUNCLUB_HAS_PROMINENT_TAB_ROLE")
    base["SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator27.*]"] =
        .string("$(inherited) SUNCLUB_HAS_PROMINENT_TAB_ROLE")

    return .settings(base: base)
}

func appTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.appTargetName,
        destinations: .iOS,
        product: .app,
        bundleId: flavor.bundleID,
        deploymentTargets: defaultDeploymentTarget,
        infoPlist: .file(path: "Info.plist"),
        sources: [
            "Sources/**"
        ],
        resources: [
            "Resources/**"
        ],
        entitlements: "Sunclub.entitlements",
        dependencies: [
            .target(name: flavor.widgetTargetName),
            .target(name: flavor.watchTargetName)
        ],
        settings: targetSettings(for: flavor, supportedPlatforms: "iphoneos iphonesimulator")
    )
}

func widgetTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.widgetTargetName,
        destinations: .iOS,
        product: .appExtension,
        bundleId: flavor.widgetBundleID,
        deploymentTargets: defaultDeploymentTarget,
        infoPlist: .extendingDefault(with: [
            "CFBundleDisplayName": "$(SUNCLUB_DISPLAY_NAME)",
            "CFBundleShortVersionString": "$(MARKETING_VERSION)",
            "CFBundleVersion": "$(SUNCLUB_BUILD_NUMBER)",
            "SunclubAppGroupID": "$(SUNCLUB_APP_GROUP_ID)",
            "SunclubICloudContainerIdentifier": "$(SUNCLUB_ICLOUD_CONTAINER)",
            "SunclubPublicAccountabilityTransportEnabled": "$(SUNCLUB_PUBLIC_ACCOUNTABILITY_TRANSPORT_ENABLED)",
            "SunclubURLScheme": "$(SUNCLUB_URL_SCHEME)",
            "NSExtension": [
                "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
            ]
        ]),
        sources: [
            "WidgetExtension/Sources/**",
            "Sources/Intents/**",
            "Sources/Models/**",
            "Sources/Services/CalendarAnalytics.swift",
            "Sources/Services/CloudSyncWireModels.swift",
            "Sources/Services/ReminderPlanner.swift",
            "Sources/Services/SunclubAccountabilityCodec.swift",
            "Sources/Services/SunclubAutomationRuntime.swift",
            "Sources/Services/SunclubBackupDocument.swift",
            "Sources/Services/SunclubBackupService.swift",
            "Sources/Services/SunclubGrowthAnalytics.swift",
            "Sources/Services/SunclubGrowthFeatureStore.swift",
            "Sources/Services/SunclubHistoricalUVStore.swift",
            "Sources/Services/SunclubHistoryService.swift",
            "Sources/Services/ManualLogSuggestions.swift",
            "Sources/Services/SunclubQuickLogAction.swift",
            "Sources/Services/SunclubShareArtifactService.swift",
            "Sources/Services/SunclubUVForecastCache.swift",
            "Sources/Services/SunclubWeatherKitBudget.swift",
            "Sources/Services/SunscreenUsageInsights.swift",
            "Sources/Shared/AppDesignSystem.swift",
            "Sources/Shared/AppRoute.swift",
            "Sources/Shared/DayPart.swift",
            "Sources/Shared/AppTheme.swift",
            "Sources/Shared/RuntimeEnvironment.swift",
            "Sources/Shared/SunManualLogInput.swift",
            "Sources/Shared/SunclubDeepLink.swift",
            "Sources/Shared/SunclubRuntimeConfiguration.swift",
            "Sources/WidgetSupport/**"
        ],
        resources: [
            "Resources/Assets.xcassets"
        ],
        entitlements: "SunclubWidgetsExtension.entitlements",
        settings: targetSettings(for: flavor, supportedPlatforms: "iphoneos iphonesimulator")
    )
}

func watchAppTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.watchTargetName,
        destinations: .watchOS,
        product: .app,
        bundleId: flavor.watchBundleID,
        deploymentTargets: defaultWatchDeploymentTarget,
        infoPlist: .extendingDefault(with: [
            "CFBundleDisplayName": .string("$(SUNCLUB_DISPLAY_NAME)"),
            "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
            "CFBundleVersion": .string("$(SUNCLUB_BUILD_NUMBER)"),
            "WKCompanionAppBundleIdentifier": .string(flavor.bundleID),
            "WKApplication": .boolean(true),
            "SunclubAppGroupID": .string("$(SUNCLUB_APP_GROUP_ID)"),
            "SunclubICloudContainerIdentifier": .string("$(SUNCLUB_ICLOUD_CONTAINER)"),
            "SunclubPublicAccountabilityTransportEnabled": .string("$(SUNCLUB_PUBLIC_ACCOUNTABILITY_TRANSPORT_ENABLED)"),
            "SunclubURLScheme": .string("$(SUNCLUB_URL_SCHEME)")
        ]),
        sources: [
            "WatchApp/Sources/**",
            "Sources/Models/AccountabilityModels.swift",
            "Sources/Models/DailyRecord.swift",
            "Sources/Models/GrowthFeatures.swift",
            "Sources/Models/SunclubRestorablePreferences.swift",
            "Sources/Models/Settings.swift",
            "Sources/Models/UVSupport.swift",
            "Sources/Models/VerificationMethod.swift",
            "Sources/Services/CalendarAnalytics.swift",
            "Sources/Services/SunclubWatchSyncCoordinator.swift",
            "Sources/Services/SunscreenUsageInsights.swift",
            "Sources/Shared/AppDesignSystem.swift",
            "Sources/Shared/AppRoute.swift",
            "Sources/Shared/DayPart.swift",
            "Sources/Shared/SunclubRuntimeConfiguration.swift",
            "Sources/WidgetSupport/SunclubWidgetSupport.swift"
        ],
        resources: [
            "WatchApp/Resources/**"
        ],
        entitlements: "SunclubWatch.entitlements",
        dependencies: [
            .target(name: flavor.watchWidgetTargetName)
        ],
        settings: targetSettings(for: flavor, supportedPlatforms: "watchos watchsimulator")
    )
}

func watchWidgetTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.watchWidgetTargetName,
        destinations: .watchOS,
        product: .appExtension,
        bundleId: flavor.watchWidgetBundleID,
        deploymentTargets: defaultWatchDeploymentTarget,
        infoPlist: .extendingDefault(with: [
            "CFBundleDisplayName": .string("$(SUNCLUB_DISPLAY_NAME)"),
            "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
            "CFBundleVersion": .string("$(SUNCLUB_BUILD_NUMBER)"),
            "SunclubAppGroupID": .string("$(SUNCLUB_APP_GROUP_ID)"),
            "SunclubICloudContainerIdentifier": .string("$(SUNCLUB_ICLOUD_CONTAINER)"),
            "SunclubPublicAccountabilityTransportEnabled": .string("$(SUNCLUB_PUBLIC_ACCOUNTABILITY_TRANSPORT_ENABLED)"),
            "SunclubURLScheme": .string("$(SUNCLUB_URL_SCHEME)"),
            "NSExtension": .dictionary([
                "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
            ])
        ]),
        sources: [
            "WatchWidgetExtension/Sources/**",
            "Sources/Models/AccountabilityModels.swift",
            "Sources/Models/DailyRecord.swift",
            "Sources/Models/GrowthFeatures.swift",
            "Sources/Models/SunclubRestorablePreferences.swift",
            "Sources/Models/Settings.swift",
            "Sources/Models/UVSupport.swift",
            "Sources/Models/VerificationMethod.swift",
            "Sources/Services/CalendarAnalytics.swift",
            "Sources/Services/SunscreenUsageInsights.swift",
            "Sources/Shared/AppDesignSystem.swift",
            "Sources/Shared/AppRoute.swift",
            "Sources/Shared/DayPart.swift",
            "Sources/Shared/SunclubRuntimeConfiguration.swift",
            "Sources/WidgetSupport/SunclubWidgetSupport.swift"
        ],
        entitlements: "SunclubWatchWidgets.entitlements",
        settings: targetSettings(for: flavor, supportedPlatforms: "watchos watchsimulator")
    )
}

func appScheme(for flavor: SunclubFlavor, includesTests: Bool) -> Scheme {
    let appTarget = TargetReference.target(flavor.appTargetName)
    let testTargets: [TestableTarget] = includesTests
        ? [
            .testableTarget(target: .target("SunclubTests"), parallelization: .disabled),
            .testableTarget(target: .target("SunclubUITests"), parallelization: .disabled)
        ]
        : []

    return .scheme(
        name: flavor.appTargetName,
        shared: true,
        buildAction: .buildAction(targets: [appTarget]),
        testAction: includesTests
            ? .targets(
                testTargets,
                configuration: .debug,
                attachDebugger: false,
                expandVariableFromTarget: appTarget
            )
            : nil,
        runAction: .runAction(
            configuration: .debug,
            attachDebugger: true,
            executable: appTarget
        ),
        archiveAction: .archiveAction(configuration: .release),
        profileAction: .profileAction(
            configuration: .release,
            executable: appTarget
        ),
        analyzeAction: .analyzeAction(configuration: .debug)
    )
}

let project = Project(
    name: "Sunclub",
    settings: {
        var base = SettingsDictionary()
            .marketingVersion(marketingVersion)
            .currentProjectVersion(currentProjectVersion)
        base["SUNCLUB_BUILD_NUMBER"] = .string(buildNumber)
        return .settings(base: base)
    }(),
    targets: [
        appTarget(for: productionFlavor),
        widgetTarget(for: productionFlavor),
        watchAppTarget(for: productionFlavor),
        watchWidgetTarget(for: productionFlavor),
        appTarget(for: developmentFlavor),
        widgetTarget(for: developmentFlavor),
        watchAppTarget(for: developmentFlavor),
        watchWidgetTarget(for: developmentFlavor),
        .target(
            name: "SunclubTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.sunclub.dev.StaticAppTests",
            infoPlist: .file(path: "Tests.plist"),
            buildableFolders: [
                .folder("Tests")
            ],
            dependencies: [
                .target(name: productionFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(productionFlavor))
        ),
        .target(
            name: "SunclubUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "app.peyton.sunclub.dev.UITests",
            infoPlist: .file(path: "Tests.plist"),
            buildableFolders: [
                .folder("UITests")
            ],
            dependencies: [
                .target(name: productionFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(productionFlavor))
        )
    ],
    schemes: [
        appScheme(for: productionFlavor, includesTests: true),
        appScheme(for: developmentFlavor, includesTests: false)
    ]
)
