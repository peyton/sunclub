import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")
let signingTeam = "AE5E5HVG56"
let marketingVersion = Environment.SUNCLUB_MARKETING_VERSION.getString(default: "1.0.0")
let buildNumber = Environment.SUNCLUB_BUILD_NUMBER.getString(default: "1")

let project = Project(
    name: "Sunclub",
    settings: .settings(
        base: [
            "MARKETING_VERSION": .string(marketingVersion),
            "CURRENT_PROJECT_VERSION": .string(buildNumber)
        ]
    ),
    targets: [
        .target(
            name: "Sunclub",
            destinations: .iOS,
            product: .app,
            bundleId: "app.peyton.sunclub",
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
                .target(name: "SunclubWidgetsExtension")
            ],
            settings: .settings(
                base: [:]
                    .automaticCodeSigning(devTeam: signingTeam)
            )
        ),
        .target(
            name: "SunclubWidgetsExtension",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "app.peyton.sunclub.widgets",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
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
                "Sources/WidgetSupport/**"
            ],
            entitlements: "SunclubWidgetsExtension.entitlements",
            settings: .settings(
                base: [:]
                    .automaticCodeSigning(devTeam: signingTeam)
            )
        ),
        .target(
            name: "SunclubTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.sunclub.StaticAppTests",
            infoPlist: .default,
            buildableFolders: [
                .folder("Tests")
            ],
            dependencies: [
                .target(name: "Sunclub")
            ]
        ),
        .target(
            name: "SunclubUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "app.peyton.sunclub.UITests",
            infoPlist: .default,
            buildableFolders: [
                .folder("UITests")
            ],
            dependencies: [
                .target(name: "Sunclub")
            ]
        )
    ]
)
