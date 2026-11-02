import AppKit
import CoreGraphics

// 生成 1024x1024 主图标：合上的笔记本侧视 + 缝隙透出的琥珀色光。
// 所有高光都裁剪在圆角路径内，避免边缘露出白边。

let canvas: CGFloat = 1024
let inset: CGFloat = 100
let radius: CGFloat = 185

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas),
    pixelsHigh: Int(canvas),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("无法创建位图上下文")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let cg = context.cgContext

let space = CGColorSpaceCreateDeviceRGB()
let amber = NSColor(srgbRed: 1.0, green: 0.66, blue: 0.15, alpha: 1.0)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

func verticalGradient(_ rect: CGRect, _ stops: [CGColor]) {
    guard let g = CGGradient(colorsSpace: space, colors: stops as CFArray, locations: [0.0, 1.0]) else { return }
    cg.drawLinearGradient(
        g,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY),
        options: []
    )
}

/// 一块带金属质感的长板：主体竖向渐变 + 顶部高光，全部裁剪在圆角内。
func slab(_ rect: CGRect, radius: CGFloat, top: CGColor, bottom: CGColor, gloss: CGFloat, glossHeight: CGFloat) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    cg.saveGState()
    cg.addPath(path)
    cg.clip()

    verticalGradient(rect, [top, bottom])

    if gloss > 0 {
        let band = CGRect(x: rect.minX, y: rect.maxY - glossHeight, width: rect.width, height: glossHeight)
        if let g = CGGradient(colorsSpace: space,
                              colors: [color(1, 1, 1, gloss), color(1, 1, 1, 0)] as CFArray,
                              locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g,
                                  start: CGPoint(x: band.midX, y: band.maxY),
                                  end: CGPoint(x: band.midX, y: band.minY),
                                  options: [])
        }
    }
    cg.restoreGState()
}

// MARK: 底板

let board = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let boardPath = CGPath(roundedRect: board, cornerWidth: radius, cornerHeight: radius, transform: nil)

cg.saveGState()
cg.addPath(boardPath)
cg.clip()

verticalGradient(board, [color(0.17, 0.17, 0.19), color(0.07, 0.07, 0.08)])

// MARK: 底座（机身）

let base = CGRect(x: 148, y: 416, width: 728, height: 104)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -20), blur: 38, color: color(0, 0, 0, 0.60))
slab(base, radius: 30,
     top: color(0.36, 0.36, 0.40), bottom: color(0.15, 0.15, 0.17),
     gloss: 0.22, glossHeight: 13)
cg.restoreGState()

// MARK: 缝隙光

let seam = CGRect(x: 190, y: 520, width: 644, height: 16)

cg.saveGState()
cg.setShadow(offset: .zero, blur: 56, color: amber.withAlphaComponent(0.70).cgColor)
cg.setFillColor(amber.cgColor)
cg.addPath(CGPath(roundedRect: seam, cornerWidth: 9, cornerHeight: 9, transform: nil))
cg.fillPath()
cg.restoreGState()

// 中心亮、两端衰减，避免变成一根硬棒
cg.saveGState()
cg.addPath(CGPath(roundedRect: seam, cornerWidth: 9, cornerHeight: 9, transform: nil))
cg.clip()
if let g = CGGradient(colorsSpace: space,
                      colors: [
                        amber.withAlphaComponent(0.10).cgColor,
                        color(1.0, 0.86, 0.58, 0.95),
                        color(1.0, 0.90, 0.68, 1.0),
                        color(1.0, 0.86, 0.58, 0.95),
                        amber.withAlphaComponent(0.10).cgColor
                      ] as CFArray,
                      locations: [0.0, 0.18, 0.5, 0.82, 1.0]) {
    cg.drawLinearGradient(g,
                          start: CGPoint(x: seam.minX, y: seam.midY),
                          end: CGPoint(x: seam.maxX, y: seam.midY),
                          options: [])
}
cg.restoreGState()

// MARK: 盖子（屏幕背面）

let lid = CGRect(x: 190, y: 536, width: 644, height: 72)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: color(0, 0, 0, 0.50))
slab(lid, radius: 26,
     top: color(0.25, 0.25, 0.29), bottom: color(0.10, 0.10, 0.12),
     gloss: 0.30, glossHeight: 10)
cg.restoreGState()

cg.restoreGState()

// MARK: 内描边

cg.addPath(boardPath)
cg.setStrokeColor(color(1, 1, 1, 0.07))
cg.setLineWidth(2)
cg.strokePath()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 编码失败")
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png")

try png.write(to: output)
print("已生成 \(output.path)")
