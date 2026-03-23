import ProjectDescription

let tuist = Tuist(
    fullHandle: "peyton/sunclub",
    project: .tuist(
        generationOptions: .options(
            enableCaching: true
        )
    )
  )

