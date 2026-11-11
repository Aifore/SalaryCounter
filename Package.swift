// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SalaryCounter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SalaryCounter",
            path: "Sources/SalaryCounter"
        )
    ]
)
