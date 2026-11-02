import Foundation

/// 管理 `/etc/sudoers.d/clamshell`：一条只允许 `pmset -a disablesleep 0|1` 的免密规则。
///
/// 为什么不用特权 helper：SMAppService 守护进程要求有效签名身份，
/// 而本机没有 Developer ID 证书；sudoers 方案零签名依赖、内容可审计、一行可删。
enum SudoersService {

    static let filePath = "/etc/sudoers.d/clamshell"

    private static var accountName: String {
        NSUserName()
    }

    /// 规则正文。仅两条精确匹配，不多给任何权限。
    static var ruleContent: String {
        """
        # Clamshell —— 允许免密切换合盖睡眠。
        # 仅授权下面这一条命令，可安全删除本文件以撤销授权。
        \(accountName) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1

        """
    }

    /// 判断规则是否已生效。
    ///
    /// 注意不能只看 `sudo -n -l <cmd>` 的退出码：管理员账户本身带有 `(ALL) ALL`，
    /// 即使没有免密规则也会返回成功。必须确认输出里出现 NOPASSWD 与该命令。
    static func isAuthorized() -> Bool {
        let output = Shell.run(PowerService.sudoPath, ["-n", "-l"])
        guard output.ok else { return false }
        let text = output.stdout
        return text.contains("NOPASSWD") && text.contains("disablesleep")
    }

    /// 弹一次系统管理员密码框，写入并校验规则。
    static func install() -> Result<Void, ServiceError> {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clamshell-\(UUID().uuidString).sudoers")

        do {
            try ruleContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.command("无法写入临时文件：\(error.localizedDescription)"))
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let source = tempURL.path
        // install 之后立刻用 visudo 校验语法；校验失败则回滚，避免破坏 sudo 配置。
        let script = """
        /usr/bin/install -m 0440 -o root -g wheel '\(source)' '\(filePath)' \
        && /usr/sbin/visudo -c -f '\(filePath)' >/dev/null 2>&1 \
        || { /bin/rm -f '\(filePath)'; exit 1; }
        """

        let result = runPrivileged(script)
        guard result.ok else {
            if result.message.contains("User canceled") || result.message.contains("-128") {
                return .failure(.cancelled)
            }
            return .failure(.command(result.message.isEmpty ? "写入 sudoers 规则失败" : result.message))
        }

        guard isAuthorized() else {
            return .failure(.command("规则已写入但未生效，请重试"))
        }
        return .success(())
    }

    /// 撤销授权（App 卸载前调用）。
    static func uninstall() -> Result<Void, ServiceError> {
        let result = runPrivileged("/bin/rm -f '\(filePath)'")
        guard result.ok else {
            return .failure(.command(result.message))
        }
        return .success(())
    }

    // MARK: - 提权

    private static func runPrivileged(_ shellScript: String) -> Shell.Output {
        let escaped = shellScript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        return Shell.run("/usr/bin/osascript", ["-e", appleScript])
    }
}
