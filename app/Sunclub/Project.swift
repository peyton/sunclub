import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")
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
    let bundleID: String
    let widgetBundleID: String
    let appGroupID: String
    let cloudKitContainerIdentifier: String
    let displayName: String
    let urlScheme: String

    var appPathName: String { appTargetName }
}

let productionFlavor = SunclubFlavor(
    appTargetName: "Sunclub",
    widgetTargetName: "SunclubWidgetsExtension",
    bundleID: "app.peyton.sunclub",
    widgetBundleID: "app.peyton.sunclub.widgets",
    appGroupID: "group.app.peyton.sunclub",
    cloudKitContainerIdentifier: "iCloud.app.peyton.sunclub",
    displayName: "Sunclub",
    urlScheme: "sunclub"
)

let developmentFlavor = SunclubFlavor(
    appTargetName: "SunclubDev",
    widgetTargetName: "SunclubDevWidgetsExtension",
    bundleID: "app.peyton.sunclub.dev",
    widgetBundleID: "app.peyton.sunclub.dev.widgets",
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
        entitlements: "SunclubWidgetsExtension.entitlements",
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
        appTarget(for: developmentFlavor),
        widgetTarget(for: developmentFlavor),
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
                .target(name: developmentFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(developmentFlavor))
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
                .target(name: developmentFlavor.appTargetName)
            ],
            settings: .settings(base: flavorBuildSettings(developmentFlavor))
        )
    ]
)
