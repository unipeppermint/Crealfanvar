import UIKit

/// A cancellable timeline driven by elapsed time, independent of refresh rate.
final class CFVMotion: NSObject {
    private final class Target: NSObject {
        weak var motion: CFVMotion?

        @objc func tick(_ link: CADisplayLink) {
            motion?.tick()
        }
    }

    private let target = Target()
    private var link: CADisplayLink?
    private var started: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var update: ((CGFloat) -> Void)?
    private var completion: (() -> Void)?

    func start(duration: TimeInterval, update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void = {}) {
        cancel()
        self.duration = max(0.01, duration)
        self.update = update
        self.completion = completion
        started = CACurrentMediaTime()
        target.motion = self
        let link = CADisplayLink(target: target, selector: #selector(Target.tick(_:)))
        self.link = link
        link.add(to: .main, forMode: .common)
        apply(0)
    }

    private func tick() {
        let progress = min(1, CGFloat((CACurrentMediaTime() - started) / duration))
        apply(progress)
        if progress >= 1 {
            let finish = completion
            cancel()
            finish?()
        }
    }

    private func apply(_ progress: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        update?(progress)
        CATransaction.commit()
    }

    func finish() {
        apply(1)
        let finish = completion
        cancel()
        finish?()
    }

    func cancel() {
        link?.invalidate()
        link = nil
        update = nil
        completion = nil
    }

    deinit { link?.invalidate() }

    static func ease(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    static func phase(_ progress: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        ease((progress - start) / (end - start))
    }
}
