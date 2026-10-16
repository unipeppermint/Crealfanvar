import UIKit

final class CFVBoardView: UIView {
    private var buttons = [CFVTileButton]()
    private var creases = [CAShapeLayer]()
    private var creaseButtons = [UIButton]()
    var onCell: ((Int) -> Void)?
    var onSwap: ((Int, Int) -> Void)?
    var onFold: ((CFVFold) -> Void)?
    var level: CFVLevel?
    private var state: CFVState?
    private var preview: CFVFold?
    private var startPoint = CGPoint.zero
    private var startCell: Int?
    private var dragFold: CFVFold?
    private var paper: CFVFoldPresentation?
    private var foldProgress: CGFloat = 0
    private let motion = CFVMotion()
    private var overlays = [CALayer]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 8
        for index in 0..<36 {
            let button = CFVTileButton(type: .custom)
            button.accessibilityIdentifier = "cell-\(index)"
            button.addAction(UIAction { [weak self] _ in self?.onCell?(index) }, for: .touchUpInside)
            addSubview(button)
            buttons.append(button)
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        pan.cancelsTouchesInView = true
        addGestureRecognizer(pan)
        NotificationCenter.default.addObserver(self, selector: #selector(motionPreferenceChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func motionPreferenceChanged() {
        if CFVSettings.shared.reduceMotion {
            motion.finish()
            if dragFold != nil { cancelAnimation() }
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.width / 6
        for index in 0..<36 {
            buttons[index].frame = CGRect(x: CGFloat(index % 6) * side, y: CGFloat(index / 6) * side, width: side, height: side)
        }
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        drawCreases()
    }

    private func drawCreases() {
        creases.forEach { $0.removeFromSuperlayer() }
        creases.removeAll()
        creaseButtons.forEach { $0.removeFromSuperview() }
        creaseButtons.removeAll()
        guard preview == nil else { return }
        for fold in level?.folds ?? [] {
            let shape = CAShapeLayer()
            let path = UIBezierPath()
            let coordinate = CGFloat(fold.boundary) * bounds.width / 6
            path.move(to: fold.axis == "vertical" ? CGPoint(x: coordinate, y: 0) : CGPoint(x: 0, y: coordinate))
            path.addLine(to: fold.axis == "vertical" ? CGPoint(x: coordinate, y: bounds.height) : CGPoint(x: bounds.width, y: coordinate))
            shape.path = path.cgPath
            shape.strokeColor = CFVTheme.ink.cgColor
            shape.lineDashPattern = [5,4]
            shape.lineWidth = 1.8
            layer.addSublayer(shape)
            creases.append(shape)
            let hitTarget = UIButton(type: .custom)
            hitTarget.backgroundColor = .clear
            hitTarget.isAccessibilityElement = false // The 48-point crease controls provide the accessible alternative.
            hitTarget.frame = fold.axis == "vertical" ? CGRect(x: coordinate - 7, y: 0, width: 14, height: bounds.height) : CGRect(x: 0, y: coordinate - 7, width: bounds.width, height: 14)
            hitTarget.addAction(UIAction { [weak self] _ in self?.onFold?(fold) }, for: .touchUpInside)
            addSubview(hitTarget)
            creaseButtons.append(hitTarget)
        }
    }

    func render(level: CFVLevel, state: CFVState, preview: CFVFold?, selection: Int?, highlights: Set<Int> = []) {
        self.level = level
        self.state = state
        self.preview = preview
        let projection = CFVEngine.projection(preview)
        let matched = preview.map { CFVEngine.matches(state, projection: CFVEngine.projection($0)) } ?? []
        for index in 0..<36 {
            let button = buttons[index]
            let cell = projection.topCells[index]
            let tile = cell.flatMap { state.tiles[$0] }
            button.tile = tile
            button.alpha = cell == nil ? 0 : 1
            button.isEnabled = preview == nil
            button.isAccessibilityElement = cell != nil
            button.selectedPaper = selection == cell
            button.highlightedPaper = tile.map { matched.contains($0.id) } == true || (cell.map { highlights.contains($0) } ?? false)
            button.topLayer = projection.stacks[index].count > 1
            let kind = tile.map { CFVText($0.kind == .leaf ? "叶片" : $0.kind == .triangle ? "三角" : "圆纹", $0.kind == .leaf ? "leaf" : $0.kind == .triangle ? "triangle" : "circle") } ?? CFVText("空白纸面", "blank paper")
            button.accessibilityLabel = String(format: CFVText("第 %d 行，第 %d 列，%@", "Row %d, column %d, %@"), index / 6 + 1, index % 6 + 1, kind)
            button.accessibilityValue = [tile?.isTarget == true ? CFVText("菱形目标", "diamond target") : "", selection == cell ? CFVText("已选中", "selected") : "", button.topLayer ? CFVText("上层纸面，遮挡下层", "top paper, covering the lower layer") : ""].filter { !$0.isEmpty }.joined(separator: ", ")
            button.accessibilityHint = preview == nil ? CFVText("点按选择，再点相邻棋子交换。", "Select, then select an adjacent tile to swap.") : CFVText("预览中，请使用确认或取消。", "Preview. Use Confirm or Cancel.")
            if preview == nil, tile != nil {
                button.accessibilityCustomActions = [("左", "left", -1), ("右", "right", 1), ("上", "up", -6), ("下", "down", 6)].compactMap { zh, en, offset in
                    let other = index + offset
                    guard (0..<36).contains(other), abs(other / 6 - index / 6) + abs(other % 6 - index % 6) == 1, state.tiles[other] != nil else { return nil }
                    return UIAccessibilityCustomAction(name: CFVText("向" + zh + "交换", "Swap " + en)) { [weak self] _ in self?.onSwap?(index, other); return true }
                }
            } else { button.accessibilityCustomActions = nil }
        }
        drawCreases()
    }

    private func cell(at point: CGPoint) -> Int? {
        guard bounds.contains(point) else { return nil }
        return Int(point.y / (bounds.width / 6)) * 6 + Int(point.x / (bounds.width / 6))
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        guard preview == nil else { return }
        let point = gesture.location(in: self)
        if gesture.state == .began {
            cancelAnimation()
            let translation = gesture.translation(in: self)
            let origin = CGPoint(x: point.x - translation.x, y: point.y - translation.y)
            startPoint = origin
            startCell = cell(at: origin)
            dragFold = level?.folds.first { fold in
                switch fold.movingSide {
                case "right": return origin.x > bounds.maxX - 28
                case "left": return origin.x < 28
                case "top": return origin.y < 28
                default: return origin.y > bounds.maxY - 28
                }
            }
            if let fold = dragFold, let state, !CFVSettings.shared.reduceMotion {
                paper = makePaper(fold, state: state)
            }
        }
        let delta = gesture.translation(in: self)
        if let fold = dragFold {
            let distance: CGFloat
            switch fold.movingSide {
            case "right": distance = -delta.x
            case "left": distance = delta.x
            case "top": distance = delta.y
            default: distance = -delta.y
            }
            let movingCells = ["left", "top"].contains(fold.movingSide) ? fold.boundary : 6 - fold.boundary
            let travel = 2 * CGFloat(movingCells) * bounds.width / 6
            foldProgress = min(0.98, max(0, distance / travel))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            paper?.setProgress(foldProgress)
            CATransaction.commit()
            if [.ended, .cancelled, .failed].contains(gesture.state) {
                if gesture.state == .ended && distance >= 24 {
                    // Keep the current paper and angle; animateFold continues from here.
                    onFold?(fold)
                } else {
                    isUserInteractionEnabled = false
                    settlePaper(to: 0) { [weak self] in
                        guard let self, let level = self.level, let state = self.state else { return }
                        self.render(level: level, state: state, preview: nil, selection: nil)
                        self.isUserInteractionEnabled = true
                    }
                    dragFold = nil
                }
            }
            return
        }
        guard gesture.state == .ended, hypot(delta.x, delta.y) >= 24 else { return }
        if let first = startCell {
            let second = first + (abs(delta.x) > abs(delta.y) ? (delta.x > 0 ? 1 : -1) : (delta.y > 0 ? 6 : -6))
            onSwap?(first, second)
        }
    }

    func creaseNear(_ cell: Int) -> CFVFold? {
        level?.folds.first { fold in
            let coordinate = fold.axis == "vertical" ? cell % 6 : cell / 6
            return coordinate == fold.boundary || coordinate == fold.boundary - 1
        }
    }

    func shake() {
        guard !CFVSettings.shared.reduceMotion else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, -5, 5, -3, 3, 0]
        animation.duration = 0.2
        layer.add(animation, forKey: "invalid")
    }

    private func makePaper(_ fold: CFVFold, state: CFVState) -> CFVFoldPresentation {
        let cellSize = bounds.width / 6
        let crease = CGFloat(fold.boundary) * cellSize
        let vertical = fold.axis == "vertical"
        let low = ["left", "top"].contains(fold.movingSide)
        let source = vertical
            ? CGRect(x: low ? 0 : crease, y: 0, width: low ? crease : bounds.width - crease, height: bounds.height)
            : CGRect(x: 0, y: low ? 0 : crease, width: bounds.width, height: low ? crease : bounds.height - crease)
        let destination = vertical
            ? source.offsetBy(dx: low ? source.width : -source.width, dy: 0)
            : source.offsetBy(dx: 0, dy: low ? source.height : -source.height)
        let front = paperImage(state: state, fold: nil, region: source)
        let back = paperImage(state: state, fold: fold, region: destination)
        let presentation = CFVFoldPresentation(fold: fold, region: source, front: front, back: back)
        presentation.layer.position = vertical ? CGPoint(x: crease, y: bounds.midY) : CGPoint(x: bounds.midX, y: crease)
        layer.addSublayer(presentation.layer)
        buttons.enumerated().filter { fold.isMoving($0.offset) }.forEach { $0.element.alpha = 0 }
        creases.forEach { $0.opacity = 0 }
        return presentation
    }

    private func paperImage(state: CFVState, fold: CFVFold?, region: CGRect) -> UIImage {
        let projection = CFVEngine.projection(fold)
        let side = bounds.width / 6
        return UIGraphicsImageRenderer(size: region.size).image { context in
            for index in 0..<36 {
                let rect = CGRect(x: CGFloat(index % 6) * side, y: CGFloat(index / 6) * side, width: side, height: side)
                guard rect.intersects(region), let source = projection.topCells[index] else { continue }
                let tile = CFVTileButton(frame: CGRect(x: 0, y: 0, width: side, height: side))
                tile.tile = state.tiles[source]
                tile.topLayer = projection.stacks[index].count > 1
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: rect.minX - region.minX, y: rect.minY - region.minY)
                tile.draw(tile.bounds)
                context.cgContext.restoreGState()
            }
        }
    }

    private func finishPaper(completion: () -> Void) {
        // Install the real board before dropping its animated cover.
        completion()
        paper?.layer.removeFromSuperlayer()
        paper = nil
        dragFold = nil
        foldProgress = 0
    }

    private func settlePaper(to end: CGFloat, completion: @escaping () -> Void) {
        guard let paper else { completion(); return }
        let start = foldProgress
        let distance = abs(end - start)
        let duration = max(0.18, (end == 1 ? 0.72 : 0.64) * Double(pow(distance, 0.65)))
        motion.start(duration: duration, update: { [weak self, weak paper] progress in
            let fraction = start + (end - start) * CFVMotion.ease(progress)
            self?.foldProgress = fraction
            paper?.setProgress(fraction)
        }, completion: { [weak self] in
            self?.finishPaper(completion: completion)
        })
    }

    func cancelAnimation() {
        motion.cancel()
        paper?.layer.removeFromSuperlayer()
        paper = nil
        overlays.forEach { $0.removeFromSuperlayer() }
        overlays.removeAll()
        dragFold = nil
        foldProgress = 0
        alpha = 1
        if let level, let state {
            render(level: level, state: state, preview: preview, selection: nil)
        }
    }

    func animateFold(_ fold: CFVFold, completion: @escaping () -> Void) {
        guard !CFVSettings.shared.reduceMotion, let state else {
            cancelAnimation()
            completion()
            return
        }
        if paper?.fold != fold {
            cancelAnimation()
            paper = makePaper(fold, state: state)
            foldProgress = 0
            paper?.setProgress(0)
        }
        settlePaper(to: 1, completion: completion)
    }

    func animateUnfold(_ fold: CFVFold, state: CFVState, completion: @escaping () -> Void) {
        cancelAnimation()
        guard !CFVSettings.shared.reduceMotion, let level else {
            completion()
            return
        }
        render(level: level, state: state, preview: nil, selection: nil)
        paper = makePaper(fold, state: state)
        foldProgress = 1
        paper?.setProgress(1)
        settlePaper(to: 0, completion: completion)
    }

    private func snapshot(_ button: CFVTileButton) -> CALayer {
        button.layer.displayIfNeeded()
        let image = UIGraphicsImageRenderer(size: button.bounds.size).image { context in
            button.layer.render(in: context.cgContext)
        }
        let cover = CALayer()
        cover.frame = button.frame
        cover.contents = image.cgImage
        cover.contentsScale = window?.screen.scale ?? 2
        layer.addSublayer(cover)
        overlays.append(cover)
        return cover
    }

    func animateTurn(_ action: CFVAction, before: CFVState, after: CFVState, removedIDs: Set<Int>, completion: @escaping () -> Void) {
        guard let level else { completion(); return }
        if CFVSettings.shared.reduceMotion {
            render(level: level, state: after, preview: nil, selection: nil)
            motion.start(duration: 0.16, update: { [weak self] progress in
                self?.alpha = 0.85 + 0.15 * CFVMotion.ease(progress)
            }, completion: completion)
            return
        }
        if action.type == "swap", let first = action.first, let second = action.second {
            let a = snapshot(buttons[first])
            let b = snapshot(buttons[second])
            let originA = a.position
            let originB = b.position
            buttons[first].tile = nil
            buttons[second].tile = nil
            motion.start(duration: 0.32, update: { progress in
                let t = CFVMotion.ease(progress)
                a.position = CGPoint(x: originA.x + (originB.x - originA.x) * t, y: originA.y + (originB.y - originA.y) * t)
                b.position = CGPoint(x: originB.x + (originA.x - originB.x) * t, y: originB.y + (originA.y - originB.y) * t)
            }, completion: { [weak self] in
                guard let self else { return }
                var swapped = before
                swapped.tiles.swapAt(first, second)
                self.render(level: level, state: swapped, preview: nil, selection: nil)
                self.overlays.forEach { $0.removeFromSuperlayer() }
                self.overlays.removeAll()
                self.animateMatches(after: after, fold: nil, removedIDs: removedIDs, completion: completion)
            })
        } else {
            let fold = level.folds.first { $0.creaseID == action.creaseID }
            animateMatches(after: after, fold: fold, removedIDs: removedIDs, completion: completion)
        }
    }

    private func animateMatches(after: CFVState, fold: CFVFold?, removedIDs: Set<Int>, completion: @escaping () -> Void) {
        if CFVSettings.shared.reduceMotion {
            if let level { render(level: level, state: after, preview: nil, selection: nil) }
            completion()
            return
        }
        for button in buttons where button.alpha > 0 && button.tile.map({ removedIDs.contains($0.id) }) == true {
            _ = snapshot(button)
            button.tile = nil
            button.highlightedPaper = false
        }
        let matched = overlays
        motion.start(duration: 0.34, update: { progress in
            let fade = CFVMotion.phase(progress, from: 0.18, to: 1)
            let scale = 1 + 0.025 * sin(progress * .pi) - 0.07 * fade
            for tile in matched {
                tile.opacity = Float(1 - fade)
                tile.transform = CATransform3DMakeScale(scale, scale, 1)
            }
        }, completion: { [weak self] in
            guard let self, let level = self.level else { return }
            self.overlays.forEach { $0.removeFromSuperlayer() }
            self.overlays.removeAll()
            self.render(level: level, state: after, preview: fold, selection: nil)
            if let fold {
                self.animateUnfold(fold, state: after, completion: completion)
            } else {
                completion()
            }
        })
    }
}

/// Front and reverse faces prevent mirrored tile symbols at the end of a fold.
private final class CFVFoldPresentation {
    let layer = CATransformLayer()
    let fold: CFVFold
    private let shading = CAGradientLayer()
    private let shadow = CALayer()

    init(fold: CFVFold, region: CGRect, front: UIImage, back: UIImage) {
        self.fold = fold
        let vertical = fold.axis == "vertical"
        let low = ["left", "top"].contains(fold.movingSide)
        layer.bounds = CGRect(origin: .zero, size: region.size)
        layer.anchorPoint = vertical ? CGPoint(x: low ? 1 : 0, y: 0.5) : CGPoint(x: 0.5, y: low ? 1 : 0)
        shadow.frame = layer.bounds
        shadow.shadowColor = UIColor.black.cgColor
        shadow.shadowPath = UIBezierPath(rect: layer.bounds).cgPath
        layer.addSublayer(shadow)
        for (index, image) in [front, back].enumerated() {
            let face = CALayer()
            face.frame = layer.bounds
            face.contents = image.cgImage
            face.isDoubleSided = false
            if index == 1 {
                face.transform = CATransform3DMakeRotation(.pi, vertical ? 0 : 1, vertical ? 1 : 0, 0)
            }
            layer.addSublayer(face)
        }
        shading.frame = layer.bounds
        shading.colors = [UIColor.black.withAlphaComponent(0.22).cgColor, UIColor.white.withAlphaComponent(0.10).cgColor, UIColor.clear.cgColor]
        shading.locations = [0, 0.28, 1]
        shading.startPoint = vertical ? CGPoint(x: low ? 1 : 0, y: 0.5) : CGPoint(x: 0.5, y: low ? 1 : 0)
        shading.endPoint = vertical ? CGPoint(x: low ? 0 : 1, y: 0.5) : CGPoint(x: 0.5, y: low ? 0 : 1)
        layer.addSublayer(shading)
    }

    func setProgress(_ progress: CGFloat) {
        let vertical = fold.axis == "vertical"
        let sign: CGFloat = ["right", "top"].contains(fold.movingSide) ? -1 : 1
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 1100
        transform = CATransform3DRotate(transform, sign * .pi * progress, vertical ? 0 : 1, vertical ? 1 : 0, 0)
        layer.transform = transform
        let lift = sin(progress * .pi)
        shading.opacity = Float(lift)
        shadow.shadowOpacity = Float(0.08 + lift * 0.18)
        shadow.shadowRadius = 2 + lift * 14
        shadow.shadowOffset = CGSize(width: 0, height: 1 + lift * 9)
    }
}
