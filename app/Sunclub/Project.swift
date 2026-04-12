import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")
let defaultWatchDeploymentTarget: DeploymentTargets = .watchOS("11.0")
let signingTeam = Environment.teamId.getString(default: "3VDQ4656LX")
let marketingVersion = Environment.sunclubMarketingVersion.getString(default: "1.0.0")
let buildNumber = Environment.sunclubBuildNumber.getString(default: "1")
let currentProjectVersion = {
    let digits = buildNumber.filter(\.isNumber)
    return digits.isEmpty ? "1" : digits
}()

struct SunclubFlavor {
    let appTargetName: String
    let widgetTargetName: String
    let watchTargetName: String
    let watchExtensionTargetName: String
    let watchContainerTargetName: String
    let watchWidgetTargetName: String
    let bundleID: String
    let widgetBundleID: String
    let watchBundleID: String
    let watchExtensionBundleID: String
    let watchContainerBundleID: String
    let watchWidgetBundleID: String
    let appGroupID: String
    let cloudKitContainerIdentifier: String
    let displayName: String
    let urlScheme: String

    var appPathName: String { appTargetName }
}

let productionFlavor = SunclubFlavor(
    appTargetName: "Sunclub",
    widgetTargetName: "SunclubWidgetsExtension",
    watchTargetName: "SunclubWatch",
    watchExtensionTargetName: "SunclubWatchExtension",
    watchContainerTargetName: "SunclubWatchContainer",
    watchWidgetTargetName: "SunclubWatchWidgetsExtension",
    bundleID: "app.peyton.sunclub",
    widgetBundleID: "app.peyton.sunclub.widgets",
    watchBundleID: "app.peyton.sunclub.watch",
    watchExtensionBundleID: "app.peyton.sunclub.watch.extension",
    watchContainerBundleID: "app.peyton.sunclub.watch.container",
    watchWidgetBundleID: "app.peyton.sunclub.watch.widgets",
    appGroupID: "group.app.peyton.sunclub",
    cloudKitContainerIdentifier: "iCloud.app.peyton.sunclub",
    displayName: "Sunclub",
    urlScheme: "sunclub"
)

let developmentFlavor = SunclubFlavor(
    appTargetName: "SunclubDev",
    widgetTargetName: "SunclubDevWidgetsExtension",
    watchTargetName: "SunclubDevWatch",
    watchExtensionTargetName: "SunclubDevWatchExtension",
    watchContainerTargetName: "SunclubDevWatchContainer",
    watchWidgetTargetName: "SunclubDevWatchWidgetsExtension",
    bundleID: "app.peyton.sunclub.dev",
    widgetBundleID: "app.peyton.sunclub.dev.widgets",
    watchBundleID: "app.peyton.sunclub.dev.watch",
    watchExtensionBundleID: "app.peyton.sunclub.dev.watch.extension",
    watchContainerBundleID: "app.peyton.sunclub.dev.watch.container",
    watchWidgetBundleID: "app.peyton.sunclub.dev.watch.widgets",
    appGroupID: "group.app.peyton.sunclub.dev",
    cloudKitContainerIdentifier: "iCloud.app.peyton.sunclub.dev",
    displayName: "Sunclub Dev",
    urlScheme: "sunclub-dev"
)

func flavorBuildSettings(_ flavor: SunclubFlavor) -> SettingsDictionary {
    [
        "SUNCLUB_APP_GROUP_ID": .string(flavor.appGroupID),
        "SUNCLUB_ICLOUD_CONTAINER": .string(flavor.cloudKitContainerIdentifier),
        "SUNCLUB_URL_SCHEME": .string(flavor.urlScheme),
        "SUNCLUB_DISPLAY_NAME": .string(flavor.displayName)
    ]
}

func targetSettings(for flavor: SunclubFlavor) -> Settings {
    var base = SettingsDictionary()
        .automaticCodeSigning(devTeam: signingTeam)

    for (key, value) in flavorBuildSettings(flavor) {
        base[key] = value
    }

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
            .target(name: flavor.widgetTargetName)
        ],
        settings: targetSettings(for: flavor)
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
            "Sources/Services/ReminderPlanner.swift",
            "Sources/Services/SunclubQuickLogAction.swift",
            "Sources/Services/SunscreenUsageInsights.swift",
            "Sources/Shared/AppRoute.swift",
            "Sources/Shared/RuntimeEnvironment.swift",
            "Sources/Shared/SunclubDeepLink.swift",
            "Sources/Shared/SunclubRuntimeConfiguration.swift",
            "Sources/WidgetSupport/**"
        ],
        resources: [
            "Resources/Assets.xcassets"
        ],
        entitlements: "SunclubWidgetsExtension.entitlements",
        settings: targetSettings(for: flavor)
    )
}

func watchAppTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.watchTargetName,
        destinations: .watchOS,
        product: .watch2App,
        bundleId: flavor.watchBundleID,
        deploymentTargets: defaultWatchDeploymentTarget,
        infoPlist: .extendingDefault(with: [
            "CFBundleDisplayName": .string("$(SUNCLUB_DISPLAY_NAME)"),
            "SunclubAppGroupID": .string("$(SUNCLUB_APP_GROUP_ID)"),
            "SunclubICloudContainerIdentifier": .string("$(SUNCLUB_ICLOUD_CONTAINER)"),
            "SunclubURLScheme": .string("$(SUNCLUB_URL_SCHEME)"),
            "CFBundleURLTypes": .array([
                .dictionary([
                    "CFBundleURLName": .string("$(PRODUCT_BUNDLE_IDENTIFIER)"),
                    "CFBundleURLSchemes": .array([.string("$(SUNCLUB_URL_SCHEME)")])
                ])
            ]),
            "WKCompanionAppBundleIdentifier": .string(flavor.bundleID)
        ]),
        dependencies: [
            .target(name: flavor.watchExtensionTargetName)
        ],
        settings: targetSettings(for: flavor)
    )
}

func watchExtensionTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.watchExtensionTargetName,
        destinations: .watchOS,
        product: .watch2Extension,
        bundleId: flavor.watchExtensionBundleID,
        deploymentTargets: defaultWatchDeploymentTarget,
        infoPlist: .extendingDefault(with: [
            "CFBundleDisplayName": .string("$(SUNCLUB_DISPLAY_NAME)"),
            "SunclubAppGroupID": .string("$(SUNCLUB_APP_GROUP_ID)"),
            "SunclubICloudContainerIdentifier": .string("$(SUNCLUB_ICLOUD_CONTAINER)"),
            "SunclubURLScheme": .string("$(SUNCLUB_URL_SCHEME)"),
            "WKAppBundleIdentifier": .string(flavor.watchBundleID),
            "NSExtension": .dictionary([
                "NSExtensionPointIdentifier": .string("com.apple.watchkit")
            ])
        ]),
        sources: [
            "WatchApp/Sources/**",
            "Sources/Models/DailyRecord.swift",
            "Sources/Models/GrowthFeatures.swift",
            "Sources/Models/Settings.swift",
            "Sources/Models/UVSupport.swift",
            "Sources/Services/CalendarAnalytics.swift",
            "Sources/Services/SunclubWatchSyncCoordinator.swift",
            "Sources/Services/SunscreenUsageInsights.swift",
            "Sources/Shared/AppRoute.swift",
            "Sources/Shared/SunclubRuntimeConfiguration.swift",
            "Sources/WidgetSupport/SunclubWidgetSupport.swift"
        ],
        entitlements: "SunclubWatch.entitlements",
        settings: targetSettings(for: flavor)
    )
}

func watchContainerTarget(for flavor: SunclubFlavor) -> Target {
    .target(
        name: flavor.watchContainerTargetName,
        destinations: .iOS,
        product: .watch2AppContainer,
        bundleId: flavor.watchContainerBundleID,
        deploymentTargets: defaultDeploymentTarget,
        infoPlist: .extendingDefault(with: [
            "CFBundleDisplayName": .string("$(SUNCLUB_DISPLAY_NAME) Watch")
        ]),
        dependencies: [
            .target(name: flavor.watchTargetName)
        ],
        settings: targetSettings(for: flavor)
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
            "SunclubAppGroupID": .string("$(SUNCLUB_APP_GROUP_ID)"),
            "SunclubICloudContainerIdentifier": .string("$(SUNCLUB_ICLOUD_CONTAINER)"),
            "SunclubURLScheme": .string("$(SUNCLUB_URL_SCHEME)"),
            "NSExtension": .dictionary([
                "NSExtensionPointIdentifier": .string("com.apple.widgetkit-extension")
            ])
        ]),
        sources: [
            "WatchWidgetExtension/Sources/**",
            "Sources/Models/DailyRecord.swift",
            "Sources/Models/GrowthFeatures.swift",
            "Sources/Models/Settings.swift",
            "Sources/Models/UVSupport.swift",
            "Sources/Services/CalendarAnalytics.swift",
            "Sources/Services/SunscreenUsageInsights.swift",
            "Sources/Shared/AppRoute.swift",
            "Sources/Shared/SunclubRuntimeConfiguration.swift",
            "Sources/WidgetSupport/SunclubWidgetSupport.swift"
        ],
        entitlements: "SunclubWatchWidgets.entitlements",
        settings: targetSettings(for: flavor)
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
        watchExtensionTarget(for: productionFlavor),
        watchContainerTarget(for: productionFlavor),
        watchWidgetTarget(for: productionFlavor),
        appTarget(for: developmentFlavor),
        widgetTarget(for: developmentFlavor),
        watchAppTarget(for: developmentFlavor),
        watchExtensionTarget(for: developmentFlavor),
        watchContainerTarget(for: developmentFlavor),
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
    ]
)
