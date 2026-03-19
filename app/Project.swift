import ProjectDescription

let teamID = "3VDQ4656LX"
let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")

func targetSettings(marketingVersion: String, swiftVersion: String) -> Settings {
    let base: SettingsDictionary = [
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": .string(teamID),
        "MARKETING_VERSION": .string(marketingVersion),
        "SWIFT_VERSION": .string(swiftVersion),
    ]

    return .settings(base: base)
}

let appSettings = targetSettings(marketingVersion: "0.1", swiftVersion: "6.0")
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
    targets: [
        .target(
            name: "Sunclub",
            destinations: .iOS,
            product: .app,
            bundleId: "app.peyton.sunclub",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: "Sunclub/Info.plist",
            resources: [
                "Sunclub/Assets.xcassets",
                "Sunclub/StoreKit/SunclubSubscriptions.storekit",
            ],
            buildableFolders: ["Sunclub"],
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
            buildableFolders: ["SunclubTests"],
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
            buildableFolders: ["SunclubUITests"],
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
            resources: [
                .glob(
                    pattern: "FastVLM/model/**/*.json",
                    excluding: ["FastVLM/model/**/*.mlpackage/**"]
                ),
                "FastVLM/model/**/*.txt",
                "FastVLM/model/**/*.safetensors",
            ],
            buildableFolders: ["FastVLM"],
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
            buildableFolders: ["FastVLMTests"],
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
