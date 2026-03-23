import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")


let project = Project(
    name: "Sunclub",
    targets: [
        .target(
            name: "Sunclub",
            destinations: .iOS,
            product: .app,
            bundleId: "app.peyton.sunclub",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: "Info.plist",
            resources: [
                "Resources/**"
            ],
            buildableFolders: [
                .folder("Sources")
            ],
            dependencies: [
                // Target dependencies can be defined here
                // .framework(path: "Frameworks/MyFramework.framework")
                .project(target: "FastVLM", path: "../Frameworks/FastVLM"),
            ]
        ),
        .target(
            name: "SunclubTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.sunclub.StaticAppTests",
            infoPlist: "Tests.plist",
            buildableFolders: [
                .folder("Tests")
            ],
            dependencies: [
                .target(name: "Sunclub"),
            ]
        ),
    ]
)
