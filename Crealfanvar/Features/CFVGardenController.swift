import UIKit

/// An ungated, noncompetitive space for arranging and enjoying the paper creatures.
final class CFVGardenController: UIViewController {
    private let app: CFVAppCoordinator
    private let column = UIStackView()
    private let display = UIStackView()
    private let scroll = UIScrollView()

    init(app: CFVAppCoordinator) {
        self.app = app
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let paper = CFVPaperView()
        paper.atmosphere = .garden
        view = paper
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    private var composition = CFVGardenComposition.load()
    private var stage: CFVScenicStage!
    private let caption = CFVTheme.label("", size: 16, color: CFVTheme.gold, serif: true)
    private var creatureButtons = [UIButton]()
    private var lightButtons = [UIButton]()
    private var positionButtons = [UIButton]()
    private let greeting = CFVMotion()
    private let sizeSlider = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        layoutGarden()
        let header = UIStackView()
        header.spacing = 12
        let home = CFVTheme.button("", symbol: "chevron.left") { [weak self] in self?.app.home() }
        home.accessibilityLabel = CFVText("返回首页", "Back to Home")
        home.accessibilityIdentifier = "garden-home"
        home.widthAnchor.constraint(equalToConstant: 48).isActive = true
        header.addArrangedSubview(home)
        let title = CFVTheme.label(CFVText("纸间花园", "Paper Garden"), size: 24, serif: true)
        title.accessibilityTraits = .header
        header.addArrangedSubview(title)
        display.addArrangedSubview(header)

        if !app.repository.catalog.creatures.contains(where: { $0.id == composition.creatureID }) {
            composition.creatureID = "paper-deer"
        }
        stage = CFVScenicStage(id: composition.creatureID, stage: 2, style: .garden)
        stage.heightAnchor.constraint(equalToConstant: min(290, UIScreen.main.bounds.height * 0.30)).isActive = true
        stage.isUserInteractionEnabled = true
        stage.isAccessibilityElement = true
        stage.accessibilityTraits = .button
        stage.accessibilityIdentifier = "garden-scene"
        stage.accessibilityHint = CFVText("轻点打个招呼，也可使用下方按钮", "Tap to say hello, or use the button below")
        stage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sayHello)))
        stage.accessibilityCustomActions = [UIAccessibilityCustomAction(name: CFVText("打个招呼", "Say hello"), target: self, selector: #selector(accessibleHello))]
        display.addArrangedSubview(stage)
        caption.accessibilityIdentifier = "garden-caption"
        display.addArrangedSubview(caption)

        let actions = row()
        let hello = CFVTheme.button(CFVText("打个招呼", "Say hello"), symbol: "sparkles", primary: true, tone: .honey) { [weak self] in self?.sayHello() }
        hello.accessibilityIdentifier = "garden-greet"
        actions.addArrangedSubview(hello)
        let unfold = CFVTheme.button(CFVText("看它展开", "Unfold"), symbol: "wind", tone: .lavender) { [weak self] in
            self?.stopGreeting()
            self?.stage.creature.replay()
            CFVAudio.shared.play("fold")
        }
        unfold.accessibilityIdentifier = "garden-unfold"
        actions.addArrangedSubview(unfold)
        column.addArrangedSubview(actions)
        column.addArrangedSubview(CFVTheme.label(
            CFVText("没有步数，也不用通关。选一位伙伴，让它陪你待一会儿。", "No moves to count, no levels to clear. Choose a companion and stay a while."),
            size: 13, color: CFVTheme.muted))

        section(CFVText("选一位伙伴 · 六种都可自由展示", "Choose a companion · All six are available"))
        for start in stride(from: 0, to: app.repository.catalog.creatures.count, by: 2) {
            let choices = row()
            for index in start..<min(start + 2, app.repository.catalog.creatures.count) {
                let creature = app.repository.catalog.creatures[index]
                let button = CFVTheme.button(app.creatureName(creature), tone: .honey) { [weak self] in
                    guard let self else { return }
                    self.stopGreeting()
                    self.composition.creatureID = creature.id
                    self.stage.showCreature(id: creature.id)
                    self.applyComposition()
                    CFVAudio.shared.play("select")
                }
                button.accessibilityIdentifier = "garden-creature-\(index)"
                creatureButtons.append(button)
                choices.addArrangedSubview(button)
            }
            column.addArrangedSubview(choices)
        }

        section(CFVText("林间光色", "Forest light"))
        let lights = row()
        for light in CFVGardenLight.allCases {
            let button = CFVTheme.button(light.title, tone: .lavender) { [weak self] in
                self?.composition.light = light
                self?.applyComposition()
            }
            button.accessibilityIdentifier = "garden-light-" + light.rawValue
            lightButtons.append(button)
            lights.addArrangedSubview(button)
        }
        column.addArrangedSubview(lights)

        section(CFVText("摆放位置", "Placement"))
        let positions = row()
        for (index, title) in positionTitles.enumerated() {
            let button = CFVTheme.button(title) { [weak self] in
                self?.stopGreeting()
                self?.composition.position = index
                self?.applyComposition()
            }
            button.accessibilityIdentifier = "garden-position-\(index)"
            positionButtons.append(button)
            positions.addArrangedSubview(button)
        }
        column.addArrangedSubview(positions)

        section(CFVText("伙伴大小", "Companion size"))
        sizeSlider.minimumValue = 0.6
        sizeSlider.maximumValue = 1
        sizeSlider.minimumTrackTintColor = CFVTheme.gold
        sizeSlider.maximumTrackTintColor = CFVTheme.line
        sizeSlider.thumbTintColor = CFVTheme.ink
        sizeSlider.accessibilityLabel = CFVText("伙伴大小", "Companion size")
        sizeSlider.accessibilityIdentifier = "garden-size"
        sizeSlider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        sizeSlider.addTarget(self, action: #selector(changeSize), for: .valueChanged)
        column.addArrangedSubview(sizeSlider)
        column.addArrangedSubview(CFVTheme.label(
            CFVText("布置会自动保存在本机。关卡挑战与图鉴制作进度独立保留。", "Your arrangement is saved on this device. Puzzle and collection progress stay separate."),
            size: 12, color: CFVTheme.muted))
        applyComposition(save: false)
        NotificationCenter.default.addObserver(self, selector: #selector(stopGreeting), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(motionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    private func layoutGarden() {
        display.axis = .vertical
        display.spacing = 10
        display.translatesAutoresizingMaskIntoConstraints = false
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(display)
        view.addSubview(scroll)
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            display.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            display.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            display.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: display.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private var positionTitles: [String] {
        [CFVText("靠左", "Left"), CFVText("居中", "Center"), CFVText("靠右", "Right")]
    }

    private func row() -> UIStackView {
        let row = UIStackView()
        row.distribution = .fillEqually
        row.spacing = 10
        return row
    }

    private func section(_ title: String) {
        let label = CFVTheme.label(title, size: 15, color: CFVTheme.muted)
        label.textAlignment = .left
        label.accessibilityTraits = .header
        column.addArrangedSubview(label)
    }

    private func applyComposition(save: Bool = true) {
        stage.gardenLight = composition.light
        stage.creaturePosition = [0.28, 0.5, 0.72][composition.position]
        stage.creatureSize = composition.size
        let selected = app.repository.catalog.creatures.firstIndex { $0.id == composition.creatureID } ?? 0
        let name = app.creatureName(app.repository.catalog.creatures[selected])
        caption.text = name + " · " + composition.light.title
        stage.accessibilityLabel = name + " · " + CFVText("打个招呼", "Say hello")
        stage.accessibilityValue = composition.light.title + " · " + positionTitles[composition.position]
        sizeSlider.value = Float(composition.size)
        sizeSlider.accessibilityValue = "\(Int(composition.size * 100))%"
        mark(creatureButtons, selected: selected, tone: .honey)
        mark(lightButtons, selected: CFVGardenLight.allCases.firstIndex(of: composition.light) ?? 0, tone: .lavender)
        mark(positionButtons, selected: composition.position, tone: .sage)
        if save { composition.save() }
    }

    private func mark(_ buttons: [UIButton], selected: Int, tone: CFVTheme.ButtonTone) {
        for (index, button) in buttons.enumerated() {
            let active = index == selected
            var configuration = button.configuration
            configuration?.baseBackgroundColor = active ? tone.accent : tone.surface
            configuration?.baseForegroundColor = active ? CFVTheme.primaryInk : CFVTheme.ink
            configuration?.background.strokeColor = tone.accent.withAlphaComponent(active ? 1 : 0.28)
            button.configuration = configuration
            button.accessibilityTraits = active ? [.button, .selected] : .button
        }
    }

    @objc private func changeSize() {
        stopGreeting()
        composition.size = Double(sizeSlider.value)
        applyComposition()
    }

    @objc private func accessibleHello() -> Bool {
        sayHello()
        return true
    }

    @objc private func sayHello() {
        stopGreeting()
        CFVAudio.shared.play("select")
        caption.text = CFVText("听见啦，纸间的朋友在向你问好。", "A little hello from your paper companion.")
        UIAccessibility.post(notification: .announcement, argument: caption.text)
        guard !CFVSettings.shared.reduceMotion else { return }
        let creature = stage.creature
        greeting.start(duration: 1.2, update: { progress in
            let wave = sin(progress * .pi * 2) * (1 - progress)
            let lift = sin(progress * .pi) * 9
            creature.transform = CGAffineTransform(translationX: 0, y: -lift).rotated(by: wave * 0.08)
        }, completion: { creature.transform = .identity })
    }

    @objc private func stopGreeting() {
        greeting.cancel()
        stage?.creature.transform = .identity
    }

    @objc private func motionChanged() {
        if CFVSettings.shared.reduceMotion { stopGreeting() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopGreeting()
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
