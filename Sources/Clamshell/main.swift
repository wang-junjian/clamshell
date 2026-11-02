import AppKit

// 进程入口。AppDelegate 必须在此保持强引用：NSApplication.delegate 是弱引用。
MainActor.assumeIsolated {
    // 自检也可由 bundle 内的标记文件触发：通过 LaunchServices 启动时无法传参，
    // 而只有 LaunchServices 启动的进程才和用户双击时完全等价（不被沙箱包裹）。
    let selftestMarker = Bundle.main.bundlePath + "/Contents/Resources/.selftest"

    if CommandLine.arguments.contains("--snapshot") {
        Snapshot.run()
    }

    let toggleMarker = Bundle.main.bundlePath + "/Contents/Resources/.toggle-test"
    let wantsToggleTest = CommandLine.arguments.contains("--toggle-test")
        || FileManager.default.fileExists(atPath: toggleMarker)

    if CommandLine.arguments.contains("--diagnose")
        || wantsToggleTest
        || FileManager.default.fileExists(atPath: selftestMarker) {
        Diagnose.run(toggleTest: wantsToggleTest)
    }

    let app = NSApplication.shared
    // 激活策略必须在 run() 之前设定，事后修改不会生效。
    app.setActivationPolicy(.accessory)

    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
    withExtendedLifetime(delegate) {}
}
