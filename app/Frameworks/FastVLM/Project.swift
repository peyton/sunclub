import ProjectDescription

let defaultDeploymentTarget: DeploymentTargets = .iOS("18.6")

let fastVLMDependencies: [TargetDependency] = [
    .external(name: "MLX"),
    .external(name: "MLXLMCommon"),
    .external(name: "MLXVLM"),
    .external(name: "Transformers")
]

let project = Project(
    name: "FastVLM",
    targets: [
        .target(
            name: "FastVLM",
            destinations: .iOS,
            product: .framework,
            bundleId: "app.peyton.sunclub-fastVLM",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: "Info.plist",
            buildableFolders: [
                .folder("Sources")
            ],
            headers: .headers(public: ["Headers/FastVLM.h"]),
            dependencies: fastVLMDependencies
        ),
        .target(
            name: "FastVLMTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.peyton.sunclub-fastVLMTests",
            deploymentTargets: defaultDeploymentTarget,
            infoPlist: "Tests.plist",
            buildableFolders: [
                .folder("Tests")
            ],
            dependencies: [
                .target(name: "FastVLM")
            ]
        )
    ]
)
