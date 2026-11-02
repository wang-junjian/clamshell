import Foundation

/// 与 `pmset` 打交道：读取真实状态、切换 `SleepDisabled`。
enum PowerService {

    static let pmsetPath = "/usr/bin/pmset"
    static let sudoPath = "/usr/bin/sudo"

    // MARK: - 读

    /// 系统当前的 SleepDisabled 值。永远以 `pmset -g` 为准，
    /// 因为命令行、其他工具、甚至重启都可能改变它，本地缓存不可信。
    static func readSleepDisabled() -> Bool {
        let output = Shell.run(pmsetPath, ["-g"])
        guard output.ok else { return false }

        for line in output.stdout.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let first = parts.first, first.lowercased() == "sleepdisabled" else { continue }
            return parts.last.map { $0 == "1" } ?? false
        }
        return false
    }

    // MARK: - 写

    /// 免密切换。要求 sudoers 规则已安装，否则会立刻失败（`-n` 禁止交互）。
    static func setSleepDisabled(_ enabled: Bool) -> Result<Void, ServiceError> {
        let output = Shell.run(
            sudoPath,
            ["-n", pmsetPath, "-a", "disablesleep", enabled ? "1" : "0"]
        )
        guard output.ok else {
            let text = output.message
            if text.contains("password is required") || text.contains("a terminal is required") {
                return .failure(.needsAuthorization)
            }
            return .failure(.command(text.isEmpty ? "pmset 执行失败" : text))
        }
        return .success(())
    }
}

enum ServiceError: LocalizedError {
    case needsAuthorization
    case command(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .needsAuthorization:
            return "尚未获得系统授权"
        case .command(let text):
            return text
        case .cancelled:
            return "已取消授权"
        }
    }
}
