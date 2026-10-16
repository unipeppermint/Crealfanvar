import UIKit
import ImageIO

func CFVText(_ chinese: String, _ english: String) -> String {
    let language = CFVSettings.shared.language
    let code = language == "system" ? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en") : language
    guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
        return code == "zh-Hans" ? chinese : english
    }
    return bundle.localizedString(forKey: english + "|" + chinese, value: code == "zh-Hans" ? chinese : english, table: nil)
}

enum CFVTheme {
    enum ButtonTone {
        case sage, honey, lavender

        var accent: UIColor {
            switch self {
            case .sage: return CFVTheme.green
            case .honey: return CFVTheme.gold
            case .lavender: return CFVTheme.lavender
            }
        }

        var surface: UIColor {
            switch self {
            case .sage: return CFVTheme.raised
            case .honey: return UIColor(hex: "493F2D")
            case .lavender: return UIColor(hex: "3C374D")
            }
        }
    }

    static let paper = UIColor(hex: "14221F")
    static let card = UIColor(hex: "24352F")
    static let raised = UIColor(hex: "30463C")
    static let ink = UIColor(hex: "F1EFE3")
    static let green = UIColor(hex: "B6CDA0")
    static let muted = UIColor(hex: "BCC5B8")
    static let line = UIColor(hex: "52675A")
    static let primaryInk = UIColor(hex: "1B3025")
    static let lavender = UIColor(hex: "C4B2D6")
    static let gold = UIColor(hex: "D9BF83")
    static let boardPaper = UIColor(hex: "33443D")
    static let foldedPaper = UIColor(hex: "42554B")

    static func styleNavigation(_ navigation: UINavigationController) {
        navigation.overrideUserInterfaceStyle = .dark
        navigation.view.tintColor = green
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = paper
        appearance.shadowColor = line.withAlphaComponent(0.5)
        appearance.titleTextAttributes = [.foregroundColor: ink]
        appearance.largeTitleTextAttributes = [.foregroundColor: ink]
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.tintColor = green
    }

    static func font(_ size: CGFloat, weight: UIFont.Weight = .regular, serif: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = serif ? base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor : base.fontDescriptor
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(descriptor: descriptor, size: size), maximumPointSize: size * 1.45)
    }

    static func label(_ text: String, size: CGFloat = 16, color: UIColor = ink, serif: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font(size, serif: serif)
        label.textColor = color
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    static func button(_ text: String, symbol: String? = nil, primary: Bool = false, tone: ButtonTone = .sage, action: @escaping () -> Void) -> UIButton {
        let button = CFVPaperButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = text
        configuration.baseBackgroundColor = primary ? tone.accent : tone.surface
        configuration.baseForegroundColor = primary ? primaryInk : ink
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        configuration.imagePadding = 8
        configuration.background.strokeColor = primary ? tone.accent : tone.accent.withAlphaComponent(0.28)
        configuration.background.strokeWidth = 1
        if let symbol, text.isEmpty || !UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            let imageConfiguration = UIImage.SymbolConfiguration(pointSize: text.isEmpty ? 22 : 18, weight: .regular)
            configuration.image = UIImage(systemName: symbol, withConfiguration: imageConfiguration)
            configuration.preferredSymbolConfigurationForImage = imageConfiguration
        }
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = font(16, weight: .medium)
            return attributes
        }
        button.configuration = configuration
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = primary ? 0.18 : 0.055
        button.layer.shadowOffset = CGSize(width: 0, height: primary ? 4 : 2)
        button.layer.shadowRadius = primary ? 0 : 4
        button.titleLabel?.numberOfLines = 0
        button.imageView?.adjustsImageSizeForAccessibilityContentSizeCategory = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
}

extension UIColor {
    convenience init(hex: String, shade: CGFloat = 0) {
        let raw = Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        func component(_ shift: Int) -> CGFloat { min(1, max(0, CGFloat((raw >> shift) & 255) / 255 + shade)) }
        self.init(red: component(16), green: component(8), blue: component(0), alpha: 1)
    }
}

final class CFVPaperView: UIView {
    var atmosphere: CFVAtmosphere = .quiet {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        CFVTheme.paper.setFill()
        context.fill(bounds)
        atmosphere.draw(in: context, bounds: bounds)
        context.setStrokeColor(UIColor(hex: "B4A88F").withAlphaComponent(0.06).cgColor)
        context.setLineWidth(0.5)
        for index in 0..<Int(bounds.height * bounds.width / 100) {
            let x = CGFloat((index * 71 + 19) % max(1, Int(bounds.width)))
            let y = CGFloat((index * 137 + 41) % max(1, Int(bounds.height)))
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + CGFloat(index % 7 + 2), y: y + 1))
        }
        context.strokePath()
    }
}

/// Shared artwork presentation for the home, collection, game HUD and rewards.
/// Stage 0 is ivory paper, stage 1 is partially folded, and stage 2 is complete.
final class CFVCreatureView: UIView {
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    private let imageView = UIImageView()
    private let motion = CFVMotion()
    private var animationLayers = [CALayer]()
    private var replayPending = false
    private var isReplaying = false
    private var renderedPixelSize = 0
    private(set) var creatureID: String
    private(set) var stage: Int

    init(id: String, stage: Int) {
        creatureID = id
        self.stage = min(2, max(0, stage))
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        NotificationCenter.default.addObserver(self, selector: #selector(finishReplay), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(motionPreferenceChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let scale = window?.screen.scale ?? traitCollection.displayScale
        let requiredSize = min(1536, Int(ceil(min(bounds.width, bounds.height) * scale / 128)) * 128)
        if requiredSize > 0, requiredSize != renderedPixelSize {
            if isReplaying { finishReplay() }
            renderedPixelSize = requiredSize
            imageView.image = image(for: stage)
        }
        if replayPending, window != nil, requiredSize > 0 {
            replayPending = false
            DispatchQueue.main.async { [weak self] in self?.replay() }
        }
    }

    private func image(for stage: Int) -> UIImage? {
        let name = "CFV-\(creatureID)-\(stage)"
        let key = "\(name)-\(renderedPixelSize)" as NSString
        if let cached = Self.imageCache.object(forKey: key) {
            return cached
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            assertionFailure("Missing creature artwork: \(name)")
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(128, renderedPixelSize),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: thumbnail)
        Self.imageCache.setObject(image, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height)
        return image
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { finishReplay() }
    }

    @objc private func motionPreferenceChanged() {
        if CFVSettings.shared.reduceMotion { finishReplay() }
    }

    @objc private func finishReplay() {
        motion.cancel()
        animationLayers.forEach { $0.removeFromSuperlayer() }
        animationLayers.removeAll()
        imageView.isHidden = false
        imageView.alpha = 1
        isReplaying = false
        replayPending = false
    }

    func settle() {
        finishReplay()
        transform = .identity
    }

    func replay() {
        guard !isReplaying else { return }
        guard window != nil, renderedPixelSize > 0 else {
            replayPending = true
            setNeedsLayout()
            return
        }
        guard !CFVSettings.shared.reduceMotion, stage > 0 else {
            finishReplay()
            return
        }
        guard let finalImage = image(for: stage) else { return }
        isReplaying = true
        imageView.isHidden = true

        // Animate one illustration throughout: different silhouettes must not crossfade.
        let fit = min(bounds.width / finalImage.size.width, bounds.height / finalImage.size.height)
        let size = CGSize(width: finalImage.size.width * fit, height: finalImage.size.height * fit)
        var panels = [CALayer]()
        var shades = [CAGradientLayer]()
        for index in 0..<2 {
            let panel = CALayer()
            panel.bounds = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
            panel.anchorPoint = CGPoint(x: index == 0 ? 1 : 0, y: 0.5)
            panel.position = CGPoint(x: bounds.midX, y: bounds.midY)
            panel.contents = finalImage.cgImage
            panel.contentsRect = CGRect(x: CGFloat(index) / 2, y: 0, width: 0.5, height: 1)
            panel.opacity = 0
            layer.addSublayer(panel)
            animationLayers.append(panel)
            panels.append(panel)

            let shade = CAGradientLayer()
            shade.frame = panel.bounds
            shade.colors = [UIColor.black.withAlphaComponent(0.18).cgColor, UIColor.clear.cgColor]
            shade.startPoint = CGPoint(x: index == 0 ? 1 : 0, y: 0.5)
            shade.endPoint = CGPoint(x: index == 0 ? 0 : 1, y: 0.5)
            let silhouette = CALayer()
            silhouette.frame = shade.bounds
            silhouette.contents = finalImage.cgImage
            silhouette.contentsRect = panel.contentsRect
            shade.mask = silhouette
            panel.addSublayer(shade)
            shades.append(shade)
        }
        motion.start(duration: 1.35, update: { progress in
            let opening = CFVMotion.phase(progress, from: 0, to: 0.92)
            let reveal = CFVMotion.phase(progress, from: 0, to: 0.18)
            let settle = CFVMotion.ease(progress)
            for (index, panel) in panels.enumerated() {
                var transform = CATransform3DIdentity
                transform.m34 = -1 / 1400
                transform = CATransform3DTranslate(transform, 0, 7 * (1 - settle), 0)
                transform = CATransform3DRotate(transform, (index == 0 ? 1 : -1) * 1.05 * (1 - opening), 0, 1, 0)
                panel.transform = transform
                panel.opacity = Float(reveal)
                shades[index].opacity = Float(1 - opening)
            }
        }, completion: { [weak self] in
            self?.finishReplay()
        })
    }

    deinit { NotificationCenter.default.removeObserver(self) }

}

final class CFVTileButton: UIButton {
    var tile: CFVTile? { didSet { setNeedsDisplay() } }
    var highlightedPaper = false { didSet { setNeedsDisplay() } }
    var selectedPaper = false { didSet { setNeedsDisplay() } }
    var topLayer = false { didSet { setNeedsDisplay() } }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let paper = bounds.insetBy(dx: 1, dy: 1)
        let outline = UIBezierPath(roundedRect: paper, cornerRadius: 3)
        (topLayer ? CFVTheme.foldedPaper : CFVTheme.boardPaper).setFill()
        outline.fill()
        (selectedPaper || highlightedPaper ? CFVTheme.green : CFVTheme.line).setStroke()
        outline.lineWidth = selectedPaper || highlightedPaper ? 3 : 0.7
        outline.stroke()
        context.saveGState()
        outline.addClip()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
        context.setLineWidth(0.5)
        for y in stride(from: CGFloat(5), to: bounds.height, by: 7) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y + 5))
        }
        context.strokePath()
        context.restoreGState()
        guard let tile else { return }
        let box = bounds.insetBy(dx: bounds.width * 0.21, dy: bounds.height * 0.21)
        let path = UIBezierPath()
        let color: UIColor
        switch tile.kind {
        case .leaf:
            path.move(to: CGPoint(x: box.minX, y: box.maxY))
            path.addQuadCurve(to: CGPoint(x: box.maxX, y: box.minY), controlPoint: CGPoint(x: box.minX - 3, y: box.minY))
            path.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY), controlPoint: CGPoint(x: box.maxX + 3, y: box.maxY))
            color = UIColor(hex: "A9C48E")
        case .triangle:
            path.move(to: CGPoint(x: box.midX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
            path.close()
            color = UIColor(hex: "C4AFD6")
        case .circle:
            path.append(UIBezierPath(ovalIn: box))
            color = UIColor(hex: "DFA181")
        }
        context.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 1.5, color: UIColor.black.withAlphaComponent(0.18).cgColor)
        color.setFill()
        path.fill()
        context.setShadow(offset: .zero, blur: 0)
        color.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 1
        path.stroke()
        context.saveGState()
        path.addClip()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.65).cgColor)
        context.setLineWidth(0.6)
        if tile.kind == .circle {
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                context.move(to: CGPoint(x: box.midX, y: box.midY))
                context.addLine(to: CGPoint(x: box.midX + cos(angle) * box.width, y: box.midY + sin(angle) * box.height))
            }
        } else {
            context.move(to: CGPoint(x: box.minX, y: box.maxY))
            context.addLine(to: CGPoint(x: tile.kind == .leaf ? box.maxX : box.midX, y: box.minY))
            context.addLine(to: CGPoint(x: box.midX, y: box.maxY))
        }
        context.strokePath()
        context.restoreGState()
        if tile.isTarget {
            let x = bounds.maxX - 9
            let y: CGFloat = 9
            let diamond = UIBezierPath()
            diamond.move(to: CGPoint(x: x, y: y - 5))
            diamond.addLine(to: CGPoint(x: x + 5, y: y))
            diamond.addLine(to: CGPoint(x: x, y: y + 5))
            diamond.addLine(to: CGPoint(x: x - 5, y: y))
            diamond.close()
            CFVTheme.paper.setFill()
            diamond.fill()
            CFVTheme.ink.setStroke()
            diamond.lineWidth = 1.7
            diamond.stroke()
        }
    }
}
