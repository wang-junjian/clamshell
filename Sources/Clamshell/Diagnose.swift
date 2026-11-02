import Foundation

/// 无 UI 的自检：确认状态读取、电池采样、授权探测三条链路都通。
@MainActor
enum Diagnose {

    /// 自检结果同时写一份到文件：从 Finder / LaunchServices 启动时没有终端可看。
    private static var log = ""

    private static func emit(_ text: String) {
        print(text)
        log += text + "\n"
    }

    private static func flushLog() {
        try? log.write(toFile: "/tmp/clamshell-diagnose.log", atomically: true, encoding: .utf8)
    }

    static func run(toggleTest: Bool = false) -> Never {
        emit("— Clamshell 自检 —")

        let disabled = PowerService.readSleepDisabled()
        emit("SleepDisabled        : \(disabled ? "1 (合盖不睡)" : "0 (正常睡眠)")")

        let battery = BatteryService.snapshot()
        emit("电池                 : \(battery.level)%  接电源=\(battery.onAC)  充电中=\(battery.charging)  有电池=\(battery.hasBattery)")

        let authorized = SudoersService.isAuthorized()
        emit("sudoers 免密已生效   : \(authorized ? "是" : "否")")

        let probe = Shell.run(PowerService.sudoPath, ["-n", "-l"])
        emit("sudo -n -l status    : \(probe.status)")
        emit("sudo -n -l stderr    : \(probe.stderr.prefix(180).replacingOccurrences(of: "\n", with: " | "))")

        let raw = Shell.run(PowerService.pmsetPath, ["-g"])
        let line = raw.stdout
            .split(separator: "\n")
            .first { $0.lowercased().contains("sleepdisabled") }
            .map(String.init) ?? "(未找到)"
        emit("pmset -g 原始行      : \(line.trimmingCharacters(in: .whitespaces))")

        if toggleTest {
            runToggleTest()
        }
        flushLog()
        exit(0)
    }

    /// 真实走一遍「读 → 设为 1 → 读 → 设为 0 → 读」，确认 App 内的调用链路。
    private static func runToggleTest() {
        emit("— 切换测试 —")
        let before = PowerService.readSleepDisabled()
        emit("初始           : \(before)")

        switch PowerService.setSleepDisabled(true) {
        case .success: emit("设为 1         : 成功")
        case .failure(let error): emit("设为 1         : 失败 — \(error.localizedDescription)")
        }
        emit("读回           : \(PowerService.readSleepDisabled())")

        switch PowerService.setSleepDisabled(false) {
        case .success: emit("还原 0         : 成功")
        case .failure(let error): emit("还原 0         : 失败 — \(error.localizedDescription)")
        }
        emit("最终           : \(PowerService.readSleepDisabled())")
    }
}
