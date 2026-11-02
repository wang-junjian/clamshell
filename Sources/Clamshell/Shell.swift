import Foundation

/// 极小的进程调用封装。全部同步执行，调用方负责调度到合适线程。
enum Shell {

    struct Output {
        let status: Int32
        let stdout: String
        let stderr: String

        var ok: Bool { status == 0 }

        var message: String {
            let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return err.isEmpty ? out : err
        }
    }

    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String]) -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return Output(status: -1, stdout: "", stderr: error.localizedDescription)
        }

        // 必须先读完再 waitUntilExit，否则输出量大时会死锁。
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Output(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
