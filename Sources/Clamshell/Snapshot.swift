import AppKit
import SwiftUI

/// 离屏渲染面板，用于在没有交互的条件下核对视觉效果。
/// 走 `cacheDisplay` 而非 `ImageRenderer`，这样 NSSwitch / NSPopUpButton 这些
/// AppKit 控件也会真实绘制，而不是渲染成占位方块。
@MainActor
enum Snapshot {

    static func run() -> Never {
        render("off", AppModel.preview(sleepDisabled: false, level: 100, onAC: true))
        render("on", AppModel.preview(sleepDisabled: true, level: 86, onAC: true))
        render("warn", AppModel.preview(sleepDisabled: true, level: 62, onAC: false))
        print("面板快照已生成")
        exit(0)
    }

    private static func render(_ name: String, _ model: AppModel) {
        let root = PanelView(model: model)
            .background(Color(nsColor: .windowBackgroundColor))

        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        let view = hosting.view

        // 先给足空间让 SwiftUI 完成布局，再收到真实固有高度。
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 600)
        view.layoutSubtreeIfNeeded()

        let height = view.fittingSize.height
        view.frame = NSRect(x: 0, y: 0, width: 320, height: height)
        view.layoutSubtreeIfNeeded()
        view.wantsLayer = true

        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            print("无法创建位图: \(name)")
            return
        }
        view.cacheDisplay(in: bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("PNG 编码失败: \(name)")
            return
        }

        let path = "/tmp/clamshell-\(name).png"
        try? png.write(to: URL(fileURLWithPath: path))
        print("\(name): \(Int(bounds.width))x\(Int(bounds.height)) -> \(path)")
    }
}
