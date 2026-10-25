// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TodoAI", platforms: [.macOS(.v14)], products: [
    .executable(name: "todo", targets: ["TodoCLI"]),
    .executable(name: "TodoAI", targets: ["TodoApp"])
], targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "TodoCore", dependencies: ["CSQLite"], exclude: ["README.md"]),
    .executableTarget(name: "TodoCLI", dependencies: ["TodoCore"], exclude: ["README.md"]),
    .executableTarget(name: "TodoApp", dependencies: ["TodoCore"], exclude: ["README.md"]),
    .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore"]),
    .testTarget(name: "TodoAppTests", dependencies: ["TodoApp", "TodoCore"])
], swiftLanguageModes: [.v5])
