import AppKit

// 用法: swift crop.swift <输入> <x> <y> <宽> <高> <输出>
// 坐标系以左上角为原点。

let args = CommandLine.arguments
guard args.count == 7,
      let image = NSImage(contentsOfFile: args[1]),
      let x = Int(args[2]), let y = Int(args[3]),
      let w = Int(args[4]), let h = Int(args[5])
else {
    print("用法: swift crop.swift <输入> <x> <y> <宽> <高> <输出>")
    exit(1)
}

guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let cropped = cg.cropping(to: CGRect(x: x, y: y, width: w, height: h))
else {
    print("裁剪失败")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: cropped)
guard let png = rep.representation(using: .png, properties: [:]) else {
    print("编码失败")
    exit(1)
}

try png.write(to: URL(fileURLWithPath: args[6]))
print("已裁剪 \(cropped.width)x\(cropped.height) -> \(args[6])")
