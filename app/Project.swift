import ProjectDescription

let teamID = "3VDQ4656LX"
let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")
let fastVLMResourceTag = "fastvlm-model"

func targetSettings(
    marketingVersion: String,
    swiftVersion: String,
    additionalSettings: SettingsDictionary = [:]
) -> Settings {
    let base: SettingsDictionary = [
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": .string(teamID),
        "MARKETING_VERSION": .string(marketingVersion),
        "SWIFT_VERSION": .string(swiftVersion),
        "TARGETED_DEVICE_FAMILY": "1",
    ]

    return .settings(base: base.merging(additionalSettings) { _, new in new })
}

let appSettings = targetSettings(
    marketingVersion: "0.1",
    swiftVersion: "6.0",
    additionalSettings: [
        "ENABLE_ON_DEMAND_RESOURCES": "YES",
        "EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE": "YES",
    ]
)
let frameworkSettings = targetSettings(marketingVersion: "1.0", swiftVersion: "5.0")
let testSettings = targetSettings(marketingVersion: "1.0", swiftVersion: "6.0")

let fastVLMDependencies: [TargetDependency] = [
    .external(name: "MLX"),
    .external(name: "MLXFast"),
    .external(name: "MLXLMCommon"),
    .external(name: "MLXNN"),
    .external(name: "MLXRandom"),
    .external(name: "MLXVLM"),
    .external(name: "Transformers"),
]

let project = Project(
    name: "Sunclub",
    options: .options(
        automaticSchemesOptions: .disabled
    ),
    targets: [
        .target(
            name: "Sunclub",
            destinations: .iOS,
            product: .app,
            bundleId: "app.peyton.sunclub",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: "Sunclub/Info.plist",
            sources: ["Sunclub/**/*.swift"],
            resources: [
                "Sunclub/Assets.xcassets",
                .folderReference(
                    path: "Generated/FastVLMODR/model",
                    tags: [fastVLMResourceTag]
                ),
            ],
            entitlements: "Sunclub/Sunclub.entitlements",
            dependencies: [
                .target(name: "FastVLM"),
            ] + fastVLMDependencies,
            settings: appSettings
        ),
        .target(
            name: "SunclubTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.sunclubTests",
            deploymentTargets: defaultDeploymentTarget,
            sources: ["SunclubTests/**/*.swift"],
            dependencies: [
                .target(name: "Sunclub"),
            ],
            settings: testSettings
        ),
        .target(
            name: "SunclubUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "app.peyton.sunclubUITests",
            deploymentTargets: defaultDeploymentTarget,
            sources: ["SunclubUITests/**/*.swift"],
            dependencies: [
                .target(name: "Sunclub"),
            ],
            settings: testSettings
        ),
        .target(
            name: "FastVLM",
            destinations: .iOS,
            product: .framework,
            bundleId: "app.peyton.sunclub.FastVLM",
            deploymentTargets: defaultDeploymentTarget,
            sources: ["FastVLM/**/*.swift"],
            headers: .headers(public: ["FastVLM/FastVLM.h"]),
            dependencies: fastVLMDependencies,
            settings: frameworkSettings
        ),
        .target(
            name: "FastVLMTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.sunclub.FastVLMTests",
            deploymentTargets: defaultDeploymentTarget,
            sources: ["FastVLMTests/**/*.swift"],
            dependencies: [
                .target(name: "FastVLM"),
            ],
            settings: testSettings
        ),
    ],
    schemes: [
        .scheme(
            name: "Sunclub",
            buildAction: .buildAction(targets: ["Sunclub"]),
            testAction: .targets(["SunclubTests", "SunclubUITests"]),
            runAction: .runAction(executable: .executable("Sunclub"))
        ),
        .scheme(
            name: "FastVLM",
            buildAction: .buildAction(targets: ["FastVLM"]),
            testAction: .targets(["FastVLMTests"])
        ),
    ]
)
