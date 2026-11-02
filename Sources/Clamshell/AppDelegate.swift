import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        model.start()
        observeModel()

        // 开发期自检用：启动后直接把面板弹出来，便于在无人值守环境核对渲染。
        if autoShowPanel {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleClick()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.prepareForTermination() ? .terminateNow : .terminateCancel
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.image = symbolImage()
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp])
        button.toolTip = "Clamshell"
    }

    private func symbolImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Clamshell")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    @objc private func handleClick() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        model.refresh()
        resizePopover()

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 首次布局完成后尺寸才可靠，显示后再校正一次。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.resizePopover()
        }

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - 面板

    private var autoShowPanel: Bool {
        CommandLine.arguments.contains("--show-panel")
            || FileManager.default.fileExists(atPath: Bundle.main.bundlePath + "/Contents/Resources/.show-panel")
    }

    private func setupPopover() {
        let hosting = NSHostingController(rootView: PanelView(model: model))
        // 让 SwiftUI 的固有尺寸驱动 popover，避免手动算高度算错。
        hosting.sizingOptions = [.preferredContentSize]

        popover.contentViewController = hosting
        popover.behavior = autoShowPanel ? .applicationDefined : .transient
        popover.animates = true
    }

    private func resizePopover() {
        guard let controller = popover.contentViewController else { return }
        let height = controller.preferredContentSize.height
        guard height > 1 else { return }
        popover.contentSize = NSSize(width: 320, height: height)
    }

    // MARK: - 状态同步

    private func observeModel() {
        model.$sleepDisabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                self?.updateStatusAppearance(active)
            }
            .store(in: &cancellables)

        model.$notice
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.popover.isShown else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    self.resizePopover()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSPopover.didCloseNotification, object: popover)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.model.refresh()
            }
            .store(in: &cancellables)
    }

    private func updateStatusAppearance(_ active: Bool) {
        guard let button = statusItem.button else { return }
        button.contentTintColor = active ? NSColor.systemOrange : nil
        button.toolTip = active ? "Clamshell — 合盖继续运行" : "Clamshell — 合盖进入睡眠"
    }
}
