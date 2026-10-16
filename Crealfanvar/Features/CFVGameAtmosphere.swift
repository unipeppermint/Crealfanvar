import UIKit

enum CFVGardenLight: String, Codable, CaseIterable {
    case amber, dusk, moon

    var title: String {
        switch self {
        case .amber: return CFVText("暖光", "Amber")
        case .dusk: return CFVText("暮色", "Dusk")
        case .moon: return CFVText("月夜", "Moon")
        }
    }

    var glow: UIColor {
        switch self {
        case .amber: return UIColor(hex: "FFCE81")
        case .dusk: return UIColor(hex: "E3A3A0")
        case .moon: return UIColor(hex: "B3C8F2")
        }
    }

    var shade: UIColor {
        switch self {
        case .amber: return UIColor(hex: "273628")
        case .dusk: return UIColor(hex: "353041")
        case .moon: return UIColor(hex: "102439")
        }
    }
}

enum CFVAtmosphere {
    case quiet, garden, journey, collection, play, celebration

    var accent: UIColor {
        switch self {
        case .collection: return UIColor(hex: "9483A5")
        case .celebration: return UIColor(hex: "BB865C")
        default: return UIColor(hex: "819C78")
        }
    }

    func draw(in context: CGContext, bounds: CGRect) {
        let colors = [UIColor(hex: "20362D").cgColor, CFVTheme.paper.cgColor,
                      accent.withAlphaComponent(self == .play ? 0.06 : 0.11).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.55, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.width * 0.35, y: bounds.height), options: [])
        }
        guard self != .quiet else { return }

        // Layered paper hills stay below the reading and playing area.
        for index in 0..<3 {
            let y = bounds.height - CGFloat(60 + index * 24)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: y + 30))
            path.addCurve(to: CGPoint(x: bounds.width, y: y),
                          controlPoint1: CGPoint(x: bounds.width * 0.35, y: y - 90),
                          controlPoint2: CGPoint(x: bounds.width * 0.68, y: y + 65))
            path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
            path.addLine(to: CGPoint(x: 0, y: bounds.height))
            path.close()
            accent.withAlphaComponent(self == .play ? 0.035 : 0.06).setFill()
            path.fill()
        }

        for side in [CGFloat(-1), CGFloat(1)] {
            context.saveGState()
            context.translateBy(x: side < 0 ? 0 : bounds.width, y: bounds.height - 70)
            context.scaleBy(x: -side, y: 1)
            for index in 0..<5 {
                let y = -CGFloat(index) * 35
                let leaf = UIBezierPath()
                leaf.move(to: CGPoint(x: 3, y: y + 25))
                leaf.addQuadCurve(to: CGPoint(x: 48 + index * 6, y: Int(y) - 36), controlPoint: CGPoint(x: 4, y: y - 32))
                leaf.addQuadCurve(to: CGPoint(x: 3, y: y + 25), controlPoint: CGPoint(x: 56, y: y + 16))
                accent.withAlphaComponent(self == .play ? 0.055 : 0.14).setFill()
                leaf.fill()
            }
            context.restoreGState()
        }
    }
}

/// A tactile stage: illustrated scenery on Home, a specimen display elsewhere.
final class CFVScenicStage: UIView {
    enum Style { case garden, specimen, reward }

    private(set) var creature: CFVCreatureView
    var gardenLight: CFVGardenLight = .amber {
        didSet { updateLight() }
    }
    var creaturePosition: CGFloat = 0.5 {
        didSet { setNeedsLayout() }
    }
    var creatureSize: CGFloat = 1 {
        didSet { setNeedsLayout() }
    }
    private let style: Style
    private let landscape = UIImageView(image: UIImage(named: "CFV-Paper-Garden.jpg"))
    private let ground = CAShapeLayer()
    private let dusk = CAGradientLayer()
    private let glow = CAGradientLayer()
    private let fireflies = CAShapeLayer()

    init(id: String, stage: Int, style: Style) {
        self.style = style
        creature = CFVCreatureView(id: id, stage: stage)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = CFVTheme.card
        layer.cornerRadius = style == .garden ? 28 : 24
        layer.cornerCurve = .continuous
        layer.borderColor = CFVTheme.line.cgColor
        layer.borderWidth = 1.5
        clipsToBounds = true
        if style == .garden {
            landscape.contentMode = .scaleAspectFill
            landscape.clipsToBounds = true
            addSubview(landscape)
            // Local light preserves the warm clearing instead of dimming the whole image.
            dusk.locations = [0, 0.5, 1]
            layer.addSublayer(dusk)
            glow.type = .radial
            glow.startPoint = CGPoint(x: 0.28, y: 0.22)
            glow.endPoint = CGPoint(x: 0.95, y: 0.85)
            layer.addSublayer(glow)
            layer.addSublayer(fireflies)
            updateLight()
        }
        ground.fillColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.addSublayer(ground)
        addSubview(creature)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showCreature(id: String) {
        creature.removeFromSuperview()
        creature = CFVCreatureView(id: id, stage: 2)
        addSubview(creature)
        setNeedsLayout()
    }

    private func updateLight() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dusk.colors = [
            gardenLight.shade.withAlphaComponent(gardenLight == .moon ? 0.72 : 0.48).cgColor,
            gardenLight.shade.withAlphaComponent(gardenLight == .moon ? 0.5 : 0.18).cgColor,
            CFVTheme.paper.withAlphaComponent(0.74).cgColor
        ]
        glow.colors = [gardenLight.glow.withAlphaComponent(0.32).cgColor,
                       gardenLight.glow.withAlphaComponent(0).cgColor]
        fireflies.fillColor = gardenLight.glow.withAlphaComponent(0.85).cgColor
        fireflies.shadowColor = gardenLight.glow.cgColor
        fireflies.shadowOpacity = 0.8
        fireflies.shadowRadius = 5
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        landscape.frame = bounds
        dusk.frame = bounds
        glow.frame = bounds
        fireflies.frame = bounds
        let lights = UIBezierPath()
        for (x, y, radius) in [(0.12, 0.47, 1.5), (0.23, 0.28, 1.0), (0.81, 0.32, 1.5),
                               (0.87, 0.64, 1.0), (0.18, 0.78, 1.2), (0.7, 0.19, 0.9)] {
            lights.append(UIBezierPath(ovalIn: CGRect(x: bounds.width * x, y: bounds.height * y,
                                                       width: radius * 2, height: radius * 2)))
        }
        fireflies.path = lights.cgPath
        let inset = style == .garden ? bounds.width * 0.15 : 16
        let width = (bounds.width - inset * 2) * creatureSize
        let height = (bounds.height - (style == .garden ? 34 : 28)) * creatureSize
        let centerX = min(bounds.width - width / 2 - 8, max(width / 2 + 8, bounds.width * creaturePosition))
        // Set bounds/center so a greeting transform survives an unrelated layout pass.
        creature.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        creature.center = CGPoint(x: centerX, y: bounds.height - (style == .garden ? 26 : 16) - height / 2)
        ground.path = UIBezierPath(ovalIn: CGRect(x: centerX - width * 0.3, y: bounds.height - 31,
                                                 width: width * 0.6, height: 12)).cgPath
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard style != .garden, let context = UIGraphicsGetCurrentContext() else { return }
        let accent = style == .reward ? UIColor(hex: "D9BA75") : UIColor(hex: "A5B699")
        let halo = CGRect(x: bounds.midX - bounds.height * 0.41, y: bounds.height * 0.08,
                          width: bounds.height * 0.82, height: bounds.height * 0.82)
        context.setFillColor(accent.withAlphaComponent(0.08).cgColor)
        context.fillEllipse(in: halo)
        context.setStrokeColor(accent.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: halo.insetBy(dx: -9, dy: -9))
        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            let center = CGPoint(x: halo.midX, y: halo.midY)
            let radius = halo.width / 2
            context.move(to: CGPoint(x: center.x + cos(angle) * (radius + 17), y: center.y + sin(angle) * (radius + 17)))
            context.addLine(to: CGPoint(x: center.x + cos(angle) * (radius + 23), y: center.y + sin(angle) * (radius + 23)))
        }
        context.strokePath()
    }
}

final class CFVProgressRibbon: UIView {
    init(title: String, detail: String, completed: Int, total: Int, accent: UIColor = CFVTheme.green) {
        super.init(frame: .zero)
        backgroundColor = CFVTheme.card
        layer.cornerRadius = 18
        layer.borderWidth = 1
        layer.borderColor = CFVTheme.line.withAlphaComponent(0.6).cgColor
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = CFVTheme.label(title, size: 15, color: CFVTheme.ink)
        titleLabel.textAlignment = .left
        let detailLabel = CFVTheme.label(detail, size: 12, color: CFVTheme.muted)
        detailLabel.textAlignment = .left
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = accent
        progress.trackTintColor = accent.withAlphaComponent(0.12)
        progress.progress = Float(completed) / Float(max(1, total))
        progress.isAccessibilityElement = false
        progress.heightAnchor.constraint(equalToConstant: 5).isActive = true
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(progress)
        stack.addArrangedSubview(detailLabel)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// The route is purely decorative; each stop remains a standard accessible button.
final class CFVChapterRoute: UIView {
    let row = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(CFVTheme.green.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [3, 5])
        context.move(to: CGPoint(x: 20, y: bounds.midY))
        context.addLine(to: CGPoint(x: bounds.width - 20, y: bounds.midY))
        context.strokePath()
    }
}

final class CFVPaperButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            let change = {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
            if CFVSettings.shared.reduceMotion { transform = .identity }
            else { UIView.animate(withDuration: 0.16, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: change) }
        }
    }
}

/// Finite confetti, with cleanup on navigation, backgrounding and Reduce Motion.
final class CFVCelebrationView: UIView {
    private let emitter = CAEmitterLayer()
    private var cleanup: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        layer.addSublayer(emitter)
        NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(motionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func celebrate() {
        guard !CFVSettings.shared.reduceMotion, window != nil else { return }
        let sprite = UIGraphicsImageRenderer(size: CGSize(width: 9, height: 13)).image { _ in
            UIColor.white.setFill()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 2))
            path.addLine(to: CGPoint(x: 8, y: 0))
            path.addLine(to: CGPoint(x: 6, y: 13))
            path.addLine(to: CGPoint(x: 1, y: 9))
            path.close()
            path.fill()
        }
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.22)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: bounds.width * 0.6, height: 1)
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = ["8C9F76", "B19BBA", "CD9875", "DAC28C"].map { hex in
            let cell = CAEmitterCell()
            cell.contents = sprite.cgImage
            cell.color = UIColor(hex: hex).cgColor
            cell.birthRate = 24
            cell.lifetime = 2.6
            cell.velocity = 95
            cell.velocityRange = 45
            cell.emissionLongitude = -.pi / 2
            cell.emissionRange = .pi
            cell.yAcceleration = 145
            cell.spin = 1.5
            cell.spinRange = 2
            cell.scale = 0.8
            cell.scaleRange = 0.3
            cell.alphaSpeed = -0.32
            return cell
        }
        emitter.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.emitter.birthRate = 0 }
        cleanup?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        cleanup = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }

    @objc private func motionChanged() {
        if CFVSettings.shared.reduceMotion { stop() }
    }

    @objc private func stop() {
        cleanup?.cancel()
        cleanup = nil
        emitter.birthRate = 0
        emitter.emitterCells = nil
        emitter.removeFromSuperlayer()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() }
    }

    deinit { cleanup?.cancel(); NotificationCenter.default.removeObserver(self) }
}
