import AppKit
import Combine
import SwiftUI

struct Notice: Identifiable, Equatable {
    enum Kind { case info, warning, error }
    let id = UUID()
    let text: String
    let kind: Kind
}

@MainActor
final class AppModel: ObservableObject {

    private enum Keys {
        static let lowBatteryGuard = "lowBatteryGuard"
        static let hotKeyIndex = "hotKeyIndex"
    }

    /// 低于该电量且未接电源时自动还原，避免电池耗尽丢失任务。
    static let lowBatteryThreshold = 20

    @Published private(set) var sleepDisabled = false
    @Published private(set) var battery = BatterySnapshot()
    @Published private(set) var authorized = false
    @Published private(set) var busy = false
    @Published private(set) var hotKeyFailed = false
    @Published private(set) var notice: Notice?

    @Published var lowBatteryGuard: Bool {
        didSet { UserDefaults.standard.set(lowBatteryGuard, forKey: Keys.lowBatteryGuard) }
    }

    @Published var hotKeyIndex: Int {
        didSet {
            UserDefaults.standard.set(hotKeyIndex, forKey: Keys.hotKeyIndex)
            applyHotKey()
        }
    }

    /// 本 App 开启的标志。用于退出时判断是否需要询问还原。
    private(set) var engagedByApp = false

    private var pollTimer: Timer?
    private var noticeTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.lowBatteryGuard: true,
            Keys.hotKeyIndex: 0
        ])
        lowBatteryGuard = defaults.bool(forKey: Keys.lowBatteryGuard)
        hotKeyIndex = defaults.integer(forKey: Keys.hotKeyIndex)
    }

    /// 仅用于离屏渲染核对视觉，不参与运行时逻辑。
    static func preview(sleepDisabled: Bool, level: Int, onAC: Bool) -> AppModel {
        let model = AppModel()
        model.sleepDisabled = sleepDisabled
        model.battery = BatterySnapshot(level: level, onAC: onAC, charging: false, hasBattery: true)
        model.authorized = true
        return model
    }

    // MARK: - 生命周期

    func start() {
        refresh()
        applyHotKey()

        HotKeyManager.shared.onTrigger = { [weak self] in
            Task { @MainActor in
                await self?.toggle()
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
    }

    // MARK: - 状态

    func refresh() {
        sleepDisabled = PowerService.readSleepDisabled()
        battery = BatteryService.snapshot()
        enforceLowBatteryGuard()
    }

    /// 主开关。任何时候都以系统真实状态为准，避免出现"App 显示开着、系统其实睡着了"。
    ///
    /// 流程是「先尝试免密切换，被拒再引导授权」，而不是先探测权限：
    /// 探测命令在无终端环境下的返回并不可靠，真实尝试才是唯一可信的信号。
    func toggle() async {
        guard !busy else { return }
        let target = !sleepDisabled

        busy = true
        defer { busy = false }

        var result = await performSet(target)

        if case .failure(.needsAuthorization) = result {
            guard await requestAuthorization() else {
                authorized = false
                return
            }
            result = await performSet(target)
        }

        switch result {
        case .success:
            authorized = true
            engagedByApp = target
            refresh()
            if target && !battery.onAC {
                show("未接电源，请留意电量", .warning)
            }
        case .failure(.needsAuthorization):
            authorized = false
            show("授权已失效，请重新授权", .error)
        case .failure(.cancelled):
            break
        case .failure(let error):
            show(error.localizedDescription, .error)
        }
    }

    private func performSet(_ value: Bool) async -> Result<Void, ServiceError> {
        await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ServiceError>, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: PowerService.setSleepDisabled(value))
            }
        }
    }

    func requestAuthorization() async -> Bool {
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ServiceError>, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: SudoersService.install())
            }
        }

        switch result {
        case .success:
            return true
        case .failure(.cancelled):
            return false
        case .failure(let error):
            show(error.localizedDescription, .error)
            return false
        }
    }

    func revokeAuthorization() {
        _ = SudoersService.uninstall()
        authorized = SudoersService.isAuthorized()
    }

    /// 退出前的收尾：如果系统还处于"合盖不睡"，必须先让用户决定。
    func prepareForTermination() -> Bool {
        guard sleepDisabled else { return true }

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        let alert = NSAlert()
        alert.messageText = "合盖不休眠仍在开启"
        alert.informativeText = "退出后系统将保持当前状态。建议还原为正常睡眠，避免合盖后持续发热。"
        alert.addButton(withTitle: "还原并退出")
        alert.addButton(withTitle: "保持现状退出")
        alert.addButton(withTitle: "取消")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            _ = PowerService.setSleepDisabled(false)
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    // MARK: - 内部

    private func applyHotKey() {
        let preset = HotKeyPreset.all.first { $0.id == hotKeyIndex } ?? HotKeyPreset.all[0]
        let ok = HotKeyManager.shared.apply(preset)
        hotKeyFailed = !ok
        if !ok {
            show("快捷键 \(preset.title) 已被其他应用占用", .warning)
        }
    }

    private func enforceLowBatteryGuard() {
        guard lowBatteryGuard,
              sleepDisabled,
              battery.hasBattery,
              !battery.onAC,
              battery.level < Self.lowBatteryThreshold
        else { return }

        _ = PowerService.setSleepDisabled(false)
        sleepDisabled = false
        engagedByApp = false
        show("电量低于 \(Self.lowBatteryThreshold)%，已自动还原睡眠", .warning)
    }

    func show(_ text: String, _ kind: Notice.Kind) {
        let item = Notice(text: text, kind: kind)
        notice = item
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.notice?.id == item.id { self?.notice = nil }
            }
        }
    }
}
