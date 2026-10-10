import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Popvy.iconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 78, y: 78, width: 868, height: 868), xRadius: 196, yRadius: 196)
        NSGradient(starting: NSColor(srgbRed: 0.35, green: 0.49, blue: 1, alpha: 1),
                   ending: NSColor(srgbRed: 0.22, green: 0.25, blue: 0.76, alpha: 1))!.draw(in: background, angle: -90)
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: NSRect(x: 250, y: 330, width: 458, height: 442), xRadius: 64, yRadius: 64).fill()
        NSColor.white.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: NSRect(x: 280, y: 286, width: 458, height: 442), xRadius: 64, yRadius: 64).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 310, y: 242, width: 458, height: 442), xRadius: 64, yRadius: 64).fill()
        NSColor(srgbRed: 0.30, green: 0.39, blue: 0.87, alpha: 1).setFill()
        for (y, width) in [(558.0, 270.0), (468.0, 270.0), (378.0, 176.0)] {
            NSBezierPath(roundedRect: NSRect(x: 395, y: y, width: width, height: 33), xRadius: 16, yRadius: 16).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let file = destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: file)
    }
}
