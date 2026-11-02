import Carbon.HIToolbox
import Foundation

struct HotKeyPreset: Identifiable, Equatable {
    let id: Int
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32

    var isEnabled: Bool { modifiers != 0 }

    static let all: [HotKeyPreset] = [
        HotKeyPreset(id: 0, title: "⌃⌥L", keyCode: UInt32(kVK_ANSI_L),
                     modifiers: UInt32(controlKey | optionKey)),
        HotKeyPreset(id: 1, title: "⌃⌥⌘L", keyCode: UInt32(kVK_ANSI_L),
                     modifiers: UInt32(controlKey | optionKey | cmdKey)),
        HotKeyPreset(id: 2, title: "⌥⌘L", keyCode: UInt32(kVK_ANSI_L),
                     modifiers: UInt32(optionKey | cmdKey)),
        HotKeyPreset(id: 3, title: "关闭", keyCode: 0, modifiers: 0)
    ]
}

/// 用 Carbon 的 RegisterEventHotKey 做全局快捷键。
/// 相比 NSEvent 全局监听，它不需要「辅助功能」授权，也不侵入系统事件流。
final class HotKeyManager {

    static let shared = HotKeyManager()

    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {
        installHandlerIfNeeded()
    }

    @discardableResult
    func apply(_ preset: HotKeyPreset) -> Bool {
        unregister()
        guard preset.isEnabled else { return true }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5348), id: 1) // 'CLSH'
        let status = RegisterEventHotKey(
            preset.keyCode,
            preset.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    fileprivate func fire() {
        onTrigger?()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.fire()
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
