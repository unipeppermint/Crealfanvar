import UIKit
import AVFoundation

final class CFVSettings {
    static let shared = CFVSettings()
    private let defaults = UserDefaults.standard
    var language: String {
        get { defaults.string(forKey: "CFV.language") ?? "system" }
        set { defaults.set(newValue, forKey: "CFV.language") }
    }
    var music: Bool {
        get { defaults.object(forKey: "CFV.music") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "CFV.music"); CFVAudio.shared.refresh() }
    }
    var sound: Bool {
        get { defaults.object(forKey: "CFV.sound") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "CFV.sound") }
    }
    var haptics: Bool {
        get { defaults.object(forKey: "CFV.haptics") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "CFV.haptics") }
    }
    var motionReduced: Bool {
        get { defaults.bool(forKey: "CFV.reduceMotion") }
        set { defaults.set(newValue, forKey: "CFV.reduceMotion") }
    }
    var reduceMotion: Bool { motionReduced || UIAccessibility.isReduceMotionEnabled }
}

final class CFVAudio {
    static let shared = CFVAudio()
    private var music: AVAudioPlayer?
    private var effects = [String: AVAudioPlayer]()
    private var interrupted = false

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for name in ["select", "swap", "fold", "match", "fail", "win", "music"] {
            guard let url = Bundle.main.url(forResource: "CFV-" + name, withExtension: "wav"), let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            if name == "music" {
                music = player
                player.numberOfLoops = -1
            } else { effects[name] = player }
            player.prepareToPlay()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(interruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func interruption(_ notification: Notification) {
        let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        interrupted = type == AVAudioSession.InterruptionType.began.rawValue
        if interrupted { music?.pause(); effects.values.forEach { $0.stop() } }
        else { refresh() }
    }

    @objc private func background() { music?.pause(); effects.values.forEach { $0.stop() } }
    @objc func refresh() {
        if CFVSettings.shared.music && !interrupted && UIApplication.shared.applicationState == .active { music?.play() }
        else { music?.pause() }
    }
    func play(_ name: String) {
        if CFVSettings.shared.sound && !interrupted { effects[name]?.currentTime = 0; effects[name]?.play() }
        if CFVSettings.shared.haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }
}
