// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "fuji-ptp-probe",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "fuji-ptp-probe",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])],
            linkerSettings: [
                .linkedFramework("ImageCaptureCore"),
                .linkedFramework("Foundation"),
            ]
        ),
    ]
)
