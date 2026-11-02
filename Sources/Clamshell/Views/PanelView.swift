import SwiftUI

struct PanelView: View {

    @ObservedObject var model: AppModel

    private var accent: Color {
        model.sleepDisabled
            ? Color(red: 0.94, green: 0.58, blue: 0.10)
            : Color.secondary
    }

    private var symbol: String {
        model.sleepDisabled ? "laptopcomputer" : "moon.zzz"
    }

    private var title: String {
        model.sleepDisabled ? "合盖继续运行" : "合盖进入睡眠"
    }

    private var subtitle: String {
        model.sleepDisabled ? "系统不会挂起，注意散热" : "点按即可启用"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            masterCard
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            batteryRow
                .padding(.horizontal, 16)
                .padding(.bottom, model.sleepDisabled && !model.battery.onAC ? 8 : 12)

            if model.sleepDisabled && !model.battery.onAC {
                warningRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider().opacity(0.5).padding(.horizontal, 16)

            options
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if let notice = model.notice {
                noticeRow(notice)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider().opacity(0.5).padding(.horizontal, 16)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: 320)
        .fixedSize(horizontal: true, vertical: true)
        .animation(.easeInOut(duration: 0.22), value: model.sleepDisabled)
        .animation(.easeInOut(duration: 0.2), value: model.notice)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(model.sleepDisabled ? accent : Color.primary.opacity(0.25))
                .frame(width: 6, height: 6)

            Text("Clamshell")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text(model.sleepDisabled ? "已启用" : "已关闭")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 11)
    }

    // MARK: - 主开关

    private var masterCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(accent.opacity(model.sleepDisabled ? 0.15 : 0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            if model.busy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            } else {
                Capsule()
                    .fill(model.sleepDisabled ? accent : Color.primary.opacity(0.13))
                    .frame(width: 36, height: 21)
                    .overlay(alignment: model.sleepDisabled ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(width: 17, height: 17)
                            .padding(2)
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(model.sleepDisabled ? accent.opacity(0.075) : Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    model.sleepDisabled ? accent.opacity(0.35) : Color.primary.opacity(0.07),
                    lineWidth: 0.8
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            Task { await model.toggle() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("合盖休眠开关")
        .accessibilityValue(title)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 电源状态

    private var batteryRow: some View {
        HStack(spacing: 5) {
            Image(systemName: batterySymbol)
                .font(.system(size: 10.5))
            Text(powerText)
                .font(.system(size: 11))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
    }

    private var batterySymbol: String {
        guard model.battery.hasBattery else { return "powerplug.fill" }
        if model.battery.onAC && model.battery.charging { return "battery.100.bolt" }
        switch model.battery.level {
        case 88...: return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 13..<38: return "battery.25"
        default: return "battery.0"
        }
    }

    private var powerText: String {
        guard model.battery.hasBattery else { return "台式机 · 外接电源" }
        let source = model.battery.onAC
            ? (model.battery.charging ? "正在充电" : "已接电源")
            : "使用电池"
        return "电池 \(model.battery.level)% · \(source)"
    }

    private var warningRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text("未接电源，电池耗尽会丢失进行中的任务")
                .font(.system(size: 10.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(red: 0.85, green: 0.42, blue: 0.05))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.94, green: 0.58, blue: 0.10).opacity(0.10))
        )
    }

    // MARK: - 选项

    private var options: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text("低电量保护")
                    .font(.system(size: 11.5))
                Spacer(minLength: 0)
                Toggle("", isOn: $model.lowBatteryGuard)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(Color(red: 0.94, green: 0.58, blue: 0.10))
            }
            .frame(height: 30)

            HStack(spacing: 7) {
                Image(systemName: "command")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text("全局快捷键")
                    .font(.system(size: 11.5))
                Spacer(minLength: 0)
                Picker("", selection: $model.hotKeyIndex) {
                    ForEach(HotKeyPreset.all) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 92)
            }
            .frame(height: 30)
        }
    }

    // MARK: - 提示

    private func noticeRow(_ notice: Notice) -> some View {
        let color: Color
        let icon: String
        switch notice.kind {
        case .info: color = .secondary; icon = "info.circle.fill"
        case .warning: color = Color(red: 0.85, green: 0.42, blue: 0.05); icon = "exclamationmark.triangle.fill"
        case .error: color = Color(red: 0.80, green: 0.22, blue: 0.20); icon = "xmark.octagon.fill"
        }

        return HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10))
            Text(notice.text)
                .font(.system(size: 10.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }

    // MARK: - 底栏

    private var footer: some View {
        HStack(spacing: 0) {
            Text("v1.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("退出 Clamshell")
        }
    }
}
