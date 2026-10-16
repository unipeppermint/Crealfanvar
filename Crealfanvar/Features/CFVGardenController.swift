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
    private var slotButtons = [UIButton]()
    private var decorationButtons = [CFVGardenDecoration: UIButton]()
    private var backdropButtons = [CFVGardenBackdrop: UIButton]()
    private var album = CFVGardenAlbum.load()
    private var albumLoadButtons = [UIButton]()
    private var albumLabels = [UILabel]()
    private var removeButton: UIButton!
    private var helloButton: UIButton!
    private var unfoldButton: UIButton!
    private let status = CFVTheme.label("", size: 13, color: CFVTheme.gold)

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

        composition = composition.available(completed: app.progress.completed)
        stage = CFVScenicStage(id: composition.creatureID, stage: 2, style: .garden)
        stage.heightAnchor.constraint(equalToConstant: min(290, UIScreen.main.bounds.height * 0.30)).isActive = true
        stage.isUserInteractionEnabled = true
        stage.isAccessibilityElement = true
        stage.accessibilityTraits = .button
        stage.accessibilityIdentifier = "garden-scene"
        stage.accessibilityHint = CFVText("轻点打个招呼，也可使用下方按钮", "Tap to say hello, or use the button below")
        stage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(touchScene(_:))))
        stage.accessibilityCustomActions = [UIAccessibilityCustomAction(name: CFVText("打个招呼", "Say hello"), target: self, selector: #selector(accessibleHello))]
        display.addArrangedSubview(stage)
        caption.accessibilityIdentifier = "garden-caption"
        display.addArrangedSubview(caption)

        let actions = row()
        let hello = CFVTheme.button(CFVText("打个招呼", "Say hello"), symbol: "sparkles", primary: true, tone: .honey) { [weak self] in self?.sayHello() }
        helloButton = hello
        hello.accessibilityIdentifier = "garden-greet"
        actions.addArrangedSubview(hello)
        let unfold = CFVTheme.button(CFVText("看它展开", "Unfold"), symbol: "wind", tone: .lavender) { [weak self] in
            self?.stopGreeting()
            self?.stage.creature.replay()
            CFVAudio.shared.play("fold")
        }
        unfoldButton = unfold
        unfold.accessibilityIdentifier = "garden-unfold"
        actions.addArrangedSubview(unfold)
        column.addArrangedSubview(actions)
        column.addArrangedSubview(CFVTheme.label(
            CFVText("一起住进森林。选一个位置，再放入伙伴；轻点场景，与它打招呼。", "Make room for friends. Select a place, add a companion, then tap the scene to say hello."),
            size: 13, color: CFVTheme.muted))

        section(CFVText("三人小聚 · 选择要布置的位置", "A gathering of three · Choose a place"))
        let slots = row()
        for index in 0..<3 {
            let button = CFVTheme.button(positionTitles[index], tone: .lavender) { [weak self] in
                guard let self else { return }
                self.stopGreeting()
                self.composition.selectedSlot = index
                self.applyComposition()
            }
            button.accessibilityIdentifier = "garden-slot-\(index)"
            slotButtons.append(button)
            slots.addArrangedSubview(button)
        }
        column.addArrangedSubview(slots)
        removeButton = CFVTheme.button(CFVText("移走这位伙伴", "Remove this companion")) { [weak self] in
            guard let self else { return }
            self.stopGreeting()
            self.composition.removeSelected()
            self.applyComposition()
        }
        removeButton.accessibilityIdentifier = "garden-remove"
        column.addArrangedSubview(removeButton)
        section(CFVText("选一位伙伴 · 六种都可自由展示", "Choose a companion · All six are available"))
        for start in stride(from: 0, to: app.repository.catalog.creatures.count, by: 2) {
            let choices = row()
            for index in start..<min(start + 2, app.repository.catalog.creatures.count) {
                let creature = app.repository.catalog.creatures[index]
                let button = CFVTheme.button(app.creatureName(creature), tone: .honey) { [weak self] in
                    guard let self else { return }
                    self.stopGreeting()
                    self.composition.creatureID = creature.id
                    self.applyComposition()
                    CFVAudio.shared.play("select")
                }
                button.accessibilityIdentifier = "garden-creature-\(index)"
                creatureButtons.append(button)
                choices.addArrangedSubview(button)
            }
            column.addArrangedSubview(choices)
        }

        buildSceneryControls()
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
        buildAlbumControls()
        status.accessibilityIdentifier = "garden-status"
        column.addArrangedSubview(status)
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
        stage.showGarden(composition)
        let resident = composition.residents[composition.selectedSlot]
        let selected = app.repository.catalog.creatures.firstIndex { $0.id == resident?.creatureID }
        let name = selected.map { app.creatureName(app.repository.catalog.creatures[$0]) }
            ?? CFVText("空位 · 选一位伙伴加入", "Empty place · Add a companion")
        caption.text = name + " · " + composition.light.title
        let names = composition.residents.compactMap { item -> String? in
            guard let item, let creature = app.repository.catalog.creatures.first(where: { $0.id == item.creatureID }) else { return nil }
            return app.creatureName(creature)
        }
        stage.accessibilityLabel = names.joined(separator: "、") + " · " + CFVText("打个招呼", "Say hello")
        stage.accessibilityValue = composition.light.title + " · " + positionTitles[composition.position]
        stage.accessibilityHint = String(format: CFVText("花园里有 %d 位伙伴。轻点问好，或使用位置按钮选择伙伴。", "%d companions in the garden. Tap to greet, or select a place below."), composition.count)
        sizeSlider.value = Float(composition.size)
        sizeSlider.accessibilityValue = "\(Int(composition.size * 100))%"
        sizeSlider.isEnabled = resident != nil
        helloButton.isEnabled = resident != nil
        unfoldButton.isEnabled = resident != nil
        removeButton.isEnabled = resident != nil && composition.count > 1
        mark(creatureButtons, selected: selected ?? -1, tone: .honey)
        mark(lightButtons, selected: CFVGardenLight.allCases.firstIndex(of: composition.light) ?? 0, tone: .lavender)
        mark(positionButtons, selected: composition.position, tone: .sage)
        positionButtons.forEach { $0.isEnabled = resident != nil }
        mark(slotButtons, selected: composition.selectedSlot, tone: .lavender)
        for index in 0..<3 {
            let item = composition.residents[index]
            let label = item.flatMap { item in app.repository.catalog.creatures.first { $0.id == item.creatureID } }
                .map(app.creatureName) ?? CFVText("空位", "Empty")
            var configuration = slotButtons[index].configuration
            configuration?.title = positionTitles[index] + " · " + label
            configuration?.titleLineBreakMode = .byWordWrapping
            slotButtons[index].configuration = configuration
        }
        for (decoration, button) in decorationButtons {
            mark([button], selected: composition.decorations.contains(decoration) ? 0 : -1, tone: .honey)
            button.accessibilityValue = decoration.isAvailable(completed: app.progress.completed)
                ? (composition.decorations.contains(decoration) ? CFVText("已摆放", "Placed") : CFVText("未摆放", "Not placed"))
                : CFVText("尚未解锁", "Locked")
        }
        for (backdrop, button) in backdropButtons {
            mark([button], selected: composition.backdrop == backdrop ? 0 : -1, tone: .lavender)
            button.accessibilityValue = backdrop.isAvailable(completed: app.progress.completed)
                ? (composition.backdrop == backdrop ? CFVText("使用中", "In use") : CFVText("可使用", "Available"))
                : CFVText("尚未解锁", "Locked")
        }
        updateAlbumLabels()
        if save { composition.save() }
    }

    private func buildSceneryControls() {
        section(CFVText("纸间摆件 · 自由组合", "Paper props · Mix and match"))
        for start in stride(from: 0, to: CFVGardenDecoration.allCases.count, by: 2) {
            let choices = row()
            for decoration in CFVGardenDecoration.allCases[start..<start + 2] {
                let available = decoration.isAvailable(completed: app.progress.completed)
                let suffix = available ? "" : String(format: CFVText(" · 第 %d 关", " · Level %d"), decoration.requiredLevel!)
                let button = CFVTheme.button(decoration.title + suffix, symbol: available ? "leaf" : "lock", tone: .honey) { [weak self] in
                    guard let self else { return }
                    guard available else {
                        self.rewardHint(level: decoration.requiredLevel!)
                        return
                    }
                    self.stopGreeting()
                    if !self.composition.decorations.insert(decoration).inserted {
                        self.composition.decorations.remove(decoration)
                    }
                    self.applyComposition()
                }
                button.accessibilityIdentifier = "garden-prop-" + decoration.rawValue
                decorationButtons[decoration] = button
                choices.addArrangedSubview(button)
            }
            column.addArrangedSubview(choices)
        }
        section(CFVText("林间风景", "A place in the forest"))
        let backgrounds = row()
        for backdrop in CFVGardenBackdrop.allCases {
            let available = backdrop.isAvailable(completed: app.progress.completed)
            let title = backdrop.title + (available ? "" : CFVText(" · 第 20 关", " · Level 20"))
            let button = CFVTheme.button(title, symbol: available ? "mountain.2" : "lock", tone: .lavender) { [weak self] in
                guard let self else { return }
                guard available else { self.rewardHint(level: 20); return }
                self.stopGreeting()
                self.composition.backdrop = backdrop
                self.applyComposition()
            }
            button.accessibilityIdentifier = "garden-backdrop-" + backdrop.rawValue
            backdropButtons[backdrop] = button
            backgrounds.addArrangedSubview(button)
        }
        column.addArrangedSubview(backgrounds)
        column.addArrangedSubview(CFVTheme.label(CFVText("森林礼物：16 关纸灯 · 20 关池畔 · 24 关星光。已有通关记录会自动获得。", "Forest gifts: lantern at 16 · pond at 20 · stars at 24. Existing completions count."), size: 12, color: CFVTheme.muted))
    }

    private func rewardHint(level: Int) {
        status.text = String(format: CFVText("完成第 %d 关后，这份森林礼物就能用于布置。", "Complete level %d to use this forest gift."), level)
        UIAccessibility.post(notification: .announcement, argument: status.text)
        app.message(CFVText("森林礼物", "Forest gift"), status.text ?? "")
    }

    private func buildAlbumControls() {
        section(CFVText("收藏我的布置 · 三份小小风景", "Saved arrangements · Three little scenes"))
        column.addArrangedSubview(CFVTheme.label(CFVText("保存会更新对应收藏；换上收藏即可恢复整套布置。", "Save updates that slot. Load restores the complete arrangement."), size: 12, color: CFVTheme.muted))
        for index in 0..<3 {
            let summary = CFVTheme.label("", size: 12, color: CFVTheme.muted)
            summary.textAlignment = .left
            summary.accessibilityIdentifier = "garden-saved-summary-\(index)"
            albumLabels.append(summary)
            column.addArrangedSubview(summary)
            let controls = row()
            let save = CFVTheme.button(String(format: CFVText("保存布置 %d", "Save scene %d"), index + 1), symbol: "bookmark", tone: .honey) { [weak self] in
                guard let self else { return }
                self.album.scenes[index] = self.composition
                self.album.save()
                self.updateAlbumLabels()
                self.status.text = String(format: CFVText("布置 %d 已收藏", "Scene %d saved"), index + 1)
                UIAccessibility.post(notification: .announcement, argument: self.status.text)
            }
            save.accessibilityIdentifier = "garden-save-\(index)"
            controls.addArrangedSubview(save)
            let load = CFVTheme.button(String(format: CFVText("换上布置 %d", "Load scene %d"), index + 1), symbol: "arrow.uturn.backward") { [weak self] in
                guard let self, let saved = self.album.scenes[index] else { return }
                self.stopGreeting()
                self.composition = saved.available(completed: self.app.progress.completed)
                self.applyComposition()
                self.status.text = String(format: CFVText("已换上布置 %d", "Scene %d restored"), index + 1)
                UIAccessibility.post(notification: .announcement, argument: self.status.text)
            }
            load.accessibilityIdentifier = "garden-load-\(index)"
            albumLoadButtons.append(load)
            controls.addArrangedSubview(load)
            column.addArrangedSubview(controls)
        }
    }

    private func updateAlbumLabels() {
        for index in 0..<3 {
            albumLoadButtons[index].isEnabled = album.scenes[index] != nil
            guard let saved = album.scenes[index] else {
                albumLabels[index].text = String(format: CFVText("布置 %d · 尚未收藏", "Scene %d · Not saved yet"), index + 1)
                continue
            }
            albumLabels[index].text = String(format: CFVText("布置 %d · %d 位伙伴", "Scene %d · %d companions"), index + 1, saved.count)
                + " · " + saved.light.title + " · " + saved.backdrop.title
        }
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

    @objc private func touchScene(_ gesture: UITapGestureRecognizer) {
        if let slot = stage.gardenSlot(at: gesture.location(in: stage)) {
            stopGreeting()
            composition.selectedSlot = slot
            applyComposition()
        }
        sayHello()
    }

    @objc private func sayHello() {
        guard composition.residents[composition.selectedSlot] != nil else { return }
        stopGreeting()
        CFVAudio.shared.play("select")
        let id = composition.creatureID
        switch id {
        case "paper-butterfly": caption.text = CFVText("纸蝶轻轻扑翼，向你问好。", "The butterfly flutters a little hello.")
        case "folded-bird": caption.text = CFVText("折翼鸟振翅跃起，向你问好。", "The bird lifts its wings with a hello.")
        case "paper-fish": caption.text = CFVText("纸鱼悠悠摆动，向你问好。", "The fish swishes a gentle hello.")
        case "paper-rabbit": caption.text = CFVText("纸兔蹦了两下，向你问好。", "The rabbit hops twice to say hello.")
        case "paper-fox": caption.text = CFVText("纸狐侧身探望，向你问好。", "The fox peeks around to say hello.")
        default: caption.text = CFVText("纸鹿轻轻俯身，向你问好。", "The deer bows a quiet hello.")
        }
        UIAccessibility.post(notification: .announcement, argument: caption.text)
        guard !CFVSettings.shared.reduceMotion else { return }
        let creature = stage.creature
        greeting.start(duration: 1.8, update: { progress in
            let envelope = pow(sin(progress * .pi), 2)
            let wave = sin(progress * .pi * 4) * envelope
            switch id {
            case "paper-butterfly":
                creature.transform = CGAffineTransform(translationX: wave * 4, y: -envelope * 14)
                    .scaledBy(x: 1 - abs(wave) * 0.22, y: 1)
            case "folded-bird":
                creature.transform = CGAffineTransform(translationX: envelope * 6, y: -envelope * 20)
                    .rotated(by: wave * 0.08).scaledBy(x: 1 - abs(wave) * 0.1, y: 1)
            case "paper-fish":
                creature.transform = CGAffineTransform(translationX: wave * 15, y: -envelope * 3)
                    .rotated(by: wave * 0.09)
            case "paper-rabbit":
                let hop = pow(sin(progress * .pi * 2), 2)
                creature.transform = CGAffineTransform(translationX: 0, y: -hop * 20)
                    .scaledBy(x: 1 + hop * 0.03, y: 1 - hop * 0.04)
            case "paper-fox":
                creature.transform = CGAffineTransform(translationX: envelope * 11, y: 0)
                    .rotated(by: -envelope * 0.12)
            default:
                creature.transform = CGAffineTransform(translationX: envelope * 3, y: envelope * 5)
                    .rotated(by: envelope * 0.1)
            }
        }, completion: { creature.transform = .identity })
    }

    @objc private func stopGreeting() {
        greeting.cancel()
        stage?.settleGarden()
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
