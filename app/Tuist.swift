import ProjectDescription

let tuist = Tuist(
    fullHandle: "peyton/sunclub",
    project: .tuist(
        generationOptions: .options(
            optionalAuthentication: true,
            includeGenerateScheme: false,
            enableCaching: true,
            registryEnabled: true,
        )
    )
  )
