import UIKit

extension CFVGardenDecoration {
    var title: String {
        switch self {
        case .tree: return CFVText("纸树", "Paper tree")
        case .stones: return CFVText("叠石", "Pebbles")
        case .lantern: return CFVText("林间纸灯", "Paper lantern")
        case .stars: return CFVText("星光挂饰", "Star garland")
        }
    }
}

extension CFVGardenBackdrop {
    var title: String {
        self == .woodland ? CFVText("森林空地", "Forest clearing") : CFVText("静谧池畔", "Quiet pond")
    }
}

/// Small paper props are rendered at display resolution, without new bitmap assets.
final class CFVGardenScenery: UIView {
    var composition = CFVGardenComposition() {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.scaleBy(x: bounds.width / 360, y: bounds.height / 260)

        func polygon(_ points: [CGPoint], color: UIColor) {
            let path = UIBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.close()
            color.setFill()
            path.fill()
            // Fine fibers and an edge crease keep props close to the paper artwork.
            context.saveGState()
            path.addClip()
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(0.35)
            let box = path.bounds
            for index in 0..<Int(box.height / 2) {
                let y = box.minY + CGFloat(index) * 2
                let x = box.minX + CGFloat((index * 13) % max(1, Int(box.width)))
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x + 7, y: y + 1))
            }
            context.strokePath()
            context.restoreGState()
            color.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }

        if composition.backdrop == .pond {
            let water = CGRect(x: 20, y: 176, width: 320, height: 75)
            UIColor(hex: "35616A").withAlphaComponent(0.88).setFill()
            UIBezierPath(ovalIn: water).fill()
            for inset in stride(from: CGFloat(10), through: 30, by: 10) {
                composition.light.glow.withAlphaComponent(0.25).setStroke()
                let ripple = UIBezierPath(ovalIn: water.insetBy(dx: inset * 2, dy: inset / 2))
                ripple.lineWidth = 0.8
                ripple.stroke()
            }
            polygon([CGPoint(x: 60, y: 216), CGPoint(x: 280, y: 214), CGPoint(x: 294, y: 228), CGPoint(x: 53, y: 234)], color: UIColor(hex: "81725D"))
            polygon([CGPoint(x: 53, y: 234), CGPoint(x: 294, y: 228), CGPoint(x: 290, y: 233), CGPoint(x: 55, y: 239)], color: UIColor(hex: "504D40"))
        }

        if composition.decorations.contains(.tree) {
            polygon([CGPoint(x: 24, y: 229), CGPoint(x: 29, y: 121), CGPoint(x: 34, y: 229)], color: UIColor(hex: "A3926C"))
            for (y, width) in [(CGFloat(98), CGFloat(19)), (130, 25), (161, 30)] {
                polygon([CGPoint(x: 29, y: y), CGPoint(x: 29 - width, y: y + 58), CGPoint(x: 29, y: y + 49)], color: UIColor(hex: "819E72"))
                polygon([CGPoint(x: 29, y: y), CGPoint(x: 29, y: y + 49), CGPoint(x: 29 + width, y: y + 58)], color: UIColor(hex: "4A7258"))
            }
        }

        if composition.decorations.contains(.stones) {
            for (x, y, width) in [(CGFloat(267), CGFloat(239), CGFloat(43)), (278, 224, 33), (283, 212, 22)] {
                polygon([CGPoint(x: x, y: y), CGPoint(x: x + width * 0.18, y: y - 12), CGPoint(x: x + width * 0.7, y: y - 15), CGPoint(x: x + width, y: y - 5), CGPoint(x: x + width * 0.8, y: y + 3)], color: UIColor(hex: "A7A99A"))
                polygon([CGPoint(x: x, y: y), CGPoint(x: x + width * 0.7, y: y - 15), CGPoint(x: x + width * 0.45, y: y + 2)], color: UIColor(hex: "CFCCB6"))
            }
        }

        if composition.decorations.contains(.lantern) {
            context.setStrokeColor(UIColor(hex: "C7AE7F").cgColor)
            context.setLineWidth(2)
            context.move(to: CGPoint(x: 310, y: 219))
            context.addLine(to: CGPoint(x: 310, y: 46))
            context.addLine(to: CGPoint(x: 282, y: 46))
            context.addLine(to: CGPoint(x: 282, y: 65))
            context.strokePath()
            context.saveGState()
            context.setShadow(offset: .zero, blur: 22, color: UIColor(hex: "FFD58A").cgColor)
            polygon([CGPoint(x: 269, y: 65), CGPoint(x: 294, y: 65), CGPoint(x: 298, y: 93), CGPoint(x: 282, y: 104), CGPoint(x: 266, y: 93)], color: UIColor(hex: "F2CE8A"))
            context.restoreGState()
            polygon([CGPoint(x: 282, y: 66), CGPoint(x: 294, y: 65), CGPoint(x: 298, y: 93), CGPoint(x: 282, y: 104)], color: UIColor(hex: "D99F68"))
            UIColor(hex: "FCE9B5").setFill()
            UIBezierPath(ovalIn: CGRect(x: 277, y: 76, width: 8, height: 15)).fill()
        }

        if composition.decorations.contains(.stars) {
            let string = UIBezierPath()
            string.move(to: CGPoint(x: 0, y: 19))
            string.addQuadCurve(to: CGPoint(x: 360, y: 19), controlPoint: CGPoint(x: 180, y: 68))
            UIColor(hex: "BDA878").setStroke()
            string.lineWidth = 0.8
            string.stroke()
            for (index, x) in [60.0, 120, 180, 240, 300].enumerated() {
                let y = 26 + sin(CGFloat(index + 1) * .pi / 6) * 20
                let points = (0..<10).map { point -> CGPoint in
                    let angle = CGFloat(point) * .pi / 5 - .pi / 2
                    let radius: CGFloat = point.isMultiple(of: 2) ? 9 : 4
                    return CGPoint(x: x + cos(angle) * radius, y: y + sin(angle) * radius)
                }
                polygon(points, color: index.isMultiple(of: 2) ? UIColor(hex: "E5CA86") : UIColor(hex: "BDA7CD"))
            }
        }
        context.restoreGState()
    }
}

// Rewards derive from completed levels, including completions saved before this update.
enum CFVGardenGift {
    static func forLevel(_ level: Int) -> String? {
        switch level {
        case 16: return CFVGardenDecoration.lantern.title
        case 20: return CFVGardenBackdrop.pond.title
        case 24: return CFVGardenDecoration.stars.title
        default: return nil
        }
    }
}
