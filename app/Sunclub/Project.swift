import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")
let signingTeam = "AE5E5HVG56"
let marketingVersion = "1.0.0"
let buildNumber = "1"

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
            infoPlist: .extendingDefault(with: [
              "UILaunchScreen": [
                  "UIColorName": "",
                  "UIImageName": "",
              ],
          ]),
            buildableFolders: [
                .folder("Sources"),
                .folder("Resources")
            ],
            entitlements: "Sunclub.entitlements",
            dependencies: [
                .project(target: "FastVLM", path: "../Frameworks/FastVLM")
            ],
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
