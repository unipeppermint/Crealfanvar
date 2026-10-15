import AppKit
import ImageIO

// QA contact sheet only. Original generated PNGs are copied without pixel edits.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let ids = ["paper-butterfly", "folded-bird", "paper-fish", "paper-rabbit", "paper-fox", "paper-deer"]
let width = 1200
let height = 1980
let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
context.setFillColor(NSColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
for (row, id) in ids.enumerated() {
    for stage in 0...2 {
        let name = "CFV-\(id)-\(stage).png"
        let url = root.appendingPathComponent("Crealfanvar/Resources/Creatures/" + name)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Missing \(name)")
        }
        let ratio = min(360 / CGFloat(image.width), 290 / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
        let cell = CGRect(x: stage * 400, y: (5 - row) * 330, width: 400, height: 330)
        context.draw(image, in: CGRect(x: cell.midX - size.width / 2, y: cell.minY + 30, width: size.width, height: size.height))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let label = "\(id) · \(stage)/2" as NSString
        label.draw(at: CGPoint(x: cell.minX + 40, y: cell.minY + 8), withAttributes: [
            .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.darkGray
        ])
        NSGraphicsContext.restoreGraphicsState()
    }
}
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("artifacts/CFV-Artwork-18-Stages.png"))
print("Rendered 18 PNG assets on paper for visual QA")
