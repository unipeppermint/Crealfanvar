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
    private var dragPaper: CALayer?
    private var dragCompleted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.shadowColor = CFVTheme.ink.cgColor
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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
            if let fold = dragFold, !CFVSettings.shared.reduceMotion {
                dragPaper = makePaper(fold)
                for index in 0..<36 where fold.isMoving(index) { buttons[index].alpha = 0 }
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
            let fraction = min(0.98, max(0, distance / (bounds.width / 3)))
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 700
            let angle = fraction * .pi * (["left", "top"].contains(fold.movingSide) ? -1 : 1)
            transform = CATransform3DRotate(transform, angle, fold.axis == "vertical" ? 0 : 1, fold.axis == "vertical" ? 1 : 0, 0)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dragPaper?.transform = transform
            CATransaction.commit()
            if [.ended, .cancelled, .failed].contains(gesture.state) {
                dragPaper?.removeFromSuperlayer()
                dragPaper = nil
                dragFold = nil
                buttons.forEach { $0.alpha = 1 }
                if gesture.state == .ended && distance >= 24 {
                    dragCompleted = true
                    onFold?(fold)
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

    private func makePaper(_ fold: CFVFold) -> CALayer {
        let size = bounds.width / 6
        let k = CGFloat(fold.boundary) * size
        let vertical = fold.axis == "vertical"
        let low = ["left", "top"].contains(fold.movingSide)
        let region = vertical ? CGRect(x: low ? 0 : k, y: 0, width: low ? k : bounds.width - k, height: bounds.height) : CGRect(x: 0, y: low ? 0 : k, width: bounds.width, height: low ? k : bounds.height - k)
        let image = UIGraphicsImageRenderer(size: region.size).image { context in
            context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            layer.render(in: context.cgContext)
        }
        let paper = CALayer()
        paper.name = "fold-paper"
        paper.bounds = CGRect(origin: .zero, size: region.size)
        paper.anchorPoint = vertical ? CGPoint(x: low ? 1 : 0, y: 0.5) : CGPoint(x: 0.5, y: low ? 1 : 0)
        paper.position = vertical ? CGPoint(x: k, y: bounds.midY) : CGPoint(x: bounds.midX, y: k)
        paper.contents = image.cgImage
        paper.isDoubleSided = true
        paper.shadowPath = UIBezierPath(rect: paper.bounds).cgPath
        paper.shadowColor = CFVTheme.ink.cgColor
        paper.shadowOpacity = 0.2
        paper.shadowRadius = 5
        layer.addSublayer(paper)
        return paper
    }

    func cancelAnimation() {
        dragPaper?.removeFromSuperlayer()
        dragPaper = nil
        dragFold = nil
        dragCompleted = false
        layer.sublayers?.filter { $0.name == "fold-paper" }.forEach { $0.removeFromSuperlayer() }
    }

    func animateFold(_ fold: CFVFold, completion: @escaping () -> Void) {
        guard !CFVSettings.shared.reduceMotion, !dragCompleted else {
            dragCompleted = false
            completion()
            return
        }
        let paper = makePaper(fold)
        let vertical = fold.axis == "vertical"
        let low = ["left", "top"].contains(fold.movingSide)
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 700
        transform = CATransform3DRotate(transform, low ? -.pi : .pi, vertical ? 0 : 1, vertical ? 1 : 0, 0)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.42)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        CATransaction.setCompletionBlock { paper.removeFromSuperlayer(); completion() }
        paper.transform = transform
        CATransaction.commit()
    }
}
