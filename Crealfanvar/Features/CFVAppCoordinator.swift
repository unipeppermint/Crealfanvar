import UIKit

final class CFVAppCoordinator {
    let navigation: UINavigationController
    let repository: CFVRepository
    let store: CFVSaveStore
    var progress: CFVProgress
    var session: CFVSession?

    init(navigation: UINavigationController) throws {
        self.navigation = navigation
        repository = try CFVRepository()
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Paperkin")
        store = try CFVSaveStore(directory: directory, repository: repository)
        progress = store.loadProgress()
        session = store.loadSession()
        if let session, session.state.outcome == .won {
            do { progress = try store.reconcile(session, progress: progress) }
            catch { store.notices.append("progress:write-failed") }
        }
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.view.backgroundColor = CFVTheme.paper
    }

    var nextIndex: Int? { repository.levels.firstIndex { !progress.completed.contains($0.levelID) } }
    var unlockedCount: Int { repository.catalog.creatures.filter { stage($0) == 2 }.count }
    func stage(_ creature: CFVCreature) -> Int { repository.catalog.stage(creature, completed: progress.completed) }
    func creature(for level: CFVLevel) -> CFVCreature { repository.catalog.creatures.first { $0.requiredLevelIDs.contains(level.levelID) }! }
    func creatureName(_ creature: CFVCreature) -> String {
        let english = ["paper-butterfly": "Paper Butterfly", "folded-bird": "Folded Bird", "paper-fish": "Paper Fish", "paper-rabbit": "Paper Rabbit", "paper-fox": "Paper Fox", "paper-deer": "Paper Deer"]
        return CFVText(creature.name, english[creature.id] ?? "")
    }
    func home() { navigation.setViewControllers([CFVHomeController(self)], animated: false) }
    func levels() { navigation.setViewControllers([CFVLevelsController(self)], animated: false) }
    func collection() { navigation.setViewControllers([CFVCollectionController(self)], animated: false) }
    func detail(_ creature: CFVCreature) { navigation.pushViewController(CFVCreatureController(self, creature: creature), animated: true) }
    func settings() {
        guard !(navigation.topViewController is CFVSettingsController) else { return }
        navigation.pushViewController(CFVSettingsController(self), animated: true)
    }

    func refreshSettingsOrigin() {
        let pages = navigation.viewControllers.map { controller -> UIViewController in
            if controller is CFVHomeController {
                return CFVHomeController(self)
            }
            if let game = controller as? CFVGameController {
                return CFVGameController(self, level: game.level)
            }
            return controller
        }
        navigation.setViewControllers(pages, animated: false)
    }
    func help(from controller: UIViewController) { controller.present(UINavigationController(rootViewController: CFVHelpController()), animated: true) }

    func begin(_ index: Int, resume: Bool = false) {
        guard repository.levels.indices.contains(index) else { return }
        if index > 0 && !progress.completed.contains(repository.levels[index - 1].levelID) {
            message(CFVText("尚未解锁", "Still folded"), String(format: CFVText("先完成第 %02d 关。", "Complete level %02d first."), index))
            return
        }
        let level = repository.levels[index]
        if resume, let session, session.levelID == level.levelID {
            if session.state.outcome == .won { showWin(level) }
            else { navigation.setViewControllers([CFVGameController(self, level: level)], animated: false) }
            return
        }
        if let session, session.state.outcome != .won {
            let oldNumber = (repository.catalog.levelIDs.firstIndex(of: session.levelID) ?? 0) + 1
            confirm(CFVText("替换当前对局？", "Replace the current game?"), String(format: CFVText("第 %02d 关的本局操作将清空。已完成关卡和图鉴会保留。", "The current game in level %02d will be replaced. Completed levels and creatures are kept."), oldNumber), action: { self.startFresh(level) })
        } else { startFresh(level) }
    }

    func startFresh(_ level: CFVLevel) {
        let fresh = CFVSession(level: level)
        do {
            try store.saveSession(fresh)
            session = fresh
            navigation.setViewControllers([CFVGameController(self, level: level)], animated: false)
        } catch { saveError(error) }
    }

    func commit(_ candidate: CFVSession) throws {
        try store.saveSession(candidate)
        session = candidate
        if candidate.state.outcome == .won { progress = try store.reconcile(candidate, progress: progress) }
    }

    func showWin(_ level: CFVLevel) {
        guard let saved = session, saved.state.outcome == .won else { return }
        do {
            progress = try store.reconcile(saved, progress: progress)
            navigation.setViewControllers([CFVWinController(self, level: level, firstPresentation: !saved.rewardPresented)], animated: false)
            var shown = saved
            shown.rewardPresented = true
            try store.saveSession(shown)
            session = shown
        } catch {
            saveError(error, retry: { self.showWin(level) })
        }
    }

    func message(_ title: String, _ body: String) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: CFVText("知道了", "OK"), style: .default))
        top.present(alert, animated: true)
    }

    func confirm(_ title: String, _ body: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: CFVText("取消", "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: CFVText("继续", "Continue"), style: .default) { _ in action() })
        top.present(alert, animated: true)
    }

    func saveError(_ error: Error, retry: (() -> Void)? = nil) {
        let alert = UIAlertController(title: CFVText("无法保存", "Could not save"), message: CFVText("请检查设备可用空间。本次结果未完成保存；已保存的进度会保留。", "Check available device storage. This result could not be fully saved. Previously saved progress is kept."), preferredStyle: .alert)
        if let retry { alert.addAction(UIAlertAction(title: CFVText("重试", "Retry"), style: .default) { _ in retry() }) }
        alert.addAction(UIAlertAction(title: CFVText("知道了", "OK"), style: .cancel))
        top.present(alert, animated: true)
    }

    var top: UIViewController {
        var controller: UIViewController = navigation.visibleViewController ?? navigation
        while let presented = controller.presentedViewController { controller = presented }
        return controller
    }
}

class CFVPageController: UIViewController {
    let app: CFVAppCoordinator
    let column = UIStackView()
    let scroll = UIScrollView()
    private let dock = UIStackView()
    var atmosphere: CFVAtmosphere { .quiet }

    init(_ app: CFVAppCoordinator) { self.app = app; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        let paper = CFVPaperView()
        paper.atmosphere = atmosphere
        view = paper
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.overrideUserInterfaceStyle = .light
        scroll.translatesAutoresizingMaskIntoConstraints = false
        column.translatesAutoresizingMaskIntoConstraints = false
        column.axis = .vertical
        column.spacing = 16
        view.addSubview(scroll)
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    func finish(docked: Bool = false) {
        if docked {
            dock.axis = .horizontal
            dock.distribution = .fillEqually
            dock.spacing = 8
            dock.backgroundColor = CFVTheme.paper.withAlphaComponent(0.96)
            dock.layer.cornerRadius = 24
            dock.isLayoutMarginsRelativeArrangement = true
            dock.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            dock.layer.borderWidth = 1
            dock.layer.borderColor = UIColor.white.cgColor
            dock.layer.shadowColor = CFVTheme.ink.cgColor
            dock.layer.shadowOpacity = 0.08
            dock.layer.shadowRadius = 12
            dock.layer.shadowOffset = CGSize(width: 0, height: 3)
            dock.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(dock)
            dock.addArrangedSubview(CFVTheme.button(CFVText("首页", "Home"), symbol: "house", primary: self is CFVHomeController) { [weak self] in self?.app.home() })
            dock.addArrangedSubview(CFVTheme.button(CFVText("关卡", "Levels"), symbol: "square.grid.2x2", primary: self is CFVLevelsController) { [weak self] in self?.app.levels() })
            let collection = CFVTheme.button(CFVText("图鉴", "Album"), symbol: "book", primary: self is CFVCollectionController) { [weak self] in self?.app.collection() }
            collection.accessibilityLabel = CFVText("图鉴", "Collection")
            dock.addArrangedSubview(collection)
            NSLayoutConstraint.activate([
                dock.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), dock.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                dock.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
                scroll.bottomAnchor.constraint(equalTo: dock.topAnchor, constant: -8)
            ])
        } else { scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true }
    }

    func heading(_ text: String, back: (() -> Void)? = nil) {
        let row = UIStackView()
        row.spacing = 10
        if let back {
            let button = CFVTheme.button("", symbol: "chevron.left", action: back)
            button.widthAnchor.constraint(equalToConstant: 48).isActive = true
            button.accessibilityLabel = CFVText("返回", "Back")
            row.addArrangedSubview(button)
        }
        let label = CFVTheme.label(text, size: 26, serif: true)
        label.accessibilityTraits = .header
        row.addArrangedSubview(label)
        column.addArrangedSubview(row)
    }

    func art(_ creature: CFVCreature, stage: Int, height: CGFloat, style: CFVScenicStage.Style = .specimen) -> CFVCreatureView {
        let display = CFVScenicStage(id: creature.id, stage: stage, style: style)
        display.heightAnchor.constraint(equalToConstant: height).isActive = true
        column.addArrangedSubview(display)
        return display.creature
    }
}

final class CFVHomeController: CFVPageController {
    override var atmosphere: CFVAtmosphere { .garden }

    override func viewDidLoad() {
        super.viewDidLoad()
        let top = UIStackView()
        column.spacing = 12
        let wordmark = CFVTheme.label("P A P E R K I N", size: 12, color: CFVTheme.green)
        wordmark.textAlignment = .left
        top.addArrangedSubview(wordmark)
        let settings = CFVTheme.button("", symbol: "gearshape") { [weak self] in self?.app.settings() }
        settings.accessibilityLabel = CFVText("设置", "Settings")
        settings.accessibilityIdentifier = "settings"
        settings.widthAnchor.constraint(equalToConstant: 48).isActive = true
        top.addArrangedSubview(settings)
        column.addArrangedSubview(top)
        let index = app.nextIndex ?? 11
        let creature = app.creature(for: app.repository.levels[index])
        column.addArrangedSubview(CFVTheme.label(CFVText("折叠生物", "Paperkin"), size: 36, serif: true))
        column.addArrangedSubview(CFVTheme.label(CFVText("折起一角，让图案相遇", "A small fold. A new perspective."), size: 15, color: CFVTheme.muted, serif: true))
        _ = art(creature, stage: app.stage(creature), height: min(290, UIScreen.main.bounds.height * 0.32), style: .garden)
        let journey = String(format: CFVText("纸间旅程  %d / 12", "Paper journey  %d / 12"), app.progress.completed.count)
        let discovery = app.nextIndex == nil
            ? CFVText("六位纸间伙伴，已全部收集", "All six paper companions collected")
            : String(format: CFVText("正在折叠 · %@   /   已发现 %d 种生物", "Unfolding · %@   /   %d creatures found"), app.creatureName(creature), app.unlockedCount)
        column.addArrangedSubview(CFVProgressRibbon(title: journey, detail: discovery, completed: app.progress.completed.count, total: 12))
        let active = app.session.flatMap { saved in app.repository.catalog.levelIDs.firstIndex(of: saved.levelID) }
        let title = app.nextIndex == nil ? CFVText("重温关卡", "Revisit levels") : active.map { String(format: CFVText("继续第 %02d 关", "Continue level %02d"), $0 + 1) } ?? CFVText("开始折叠", "Start Folding")
        let start = CFVTheme.button(title, symbol: "arrow.right", primary: true) { [weak self] in
            guard let self else { return }
            if self.app.nextIndex == nil { self.app.levels() }
            else { self.app.begin(active ?? index, resume: active != nil) }
        }
        start.accessibilityIdentifier = "home-start"
        start.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        column.addArrangedSubview(start)
        let row = UIStackView()
        row.distribution = .fillEqually
        row.spacing = 12
        row.addArrangedSubview(CFVTheme.button(CFVText("关卡册", "Level book"), symbol: "square.grid.2x2") { [weak self] in self?.app.levels() })
        row.addArrangedSubview(CFVTheme.button(CFVText("生物图鉴", "Collection"), symbol: "book") { [weak self] in self?.app.collection() })
        column.addArrangedSubview(row)
        finish()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CFVAudio.shared.refresh()
        if !app.store.notices.isEmpty {
            let notices = app.store.notices
            app.store.notices.removeAll()
            let body = notices.contains("progress:damaged") ? CFVText("完成记录读取异常，已尝试独立备份。若备份也损坏，部分收藏无法恢复。故障文件已保留，当前对局不受清空操作影响。", "Completion records could not be read. An independent backup was attempted. If both copies are damaged, some collection progress cannot be recovered. Damaged files have been preserved.") : CFVText("当前对局读取异常，已尝试备份或重开对应关卡。已完成关卡独立保存，故障文件已保留。", "The current game could not be read. A backup or a fresh copy of its level was loaded where possible. Completion records are stored separately, and damaged files have been preserved.")
            app.message(CFVText("存档恢复", "Save recovery"), body)
        }
    }
}

final class CFVLevelsController: CFVPageController {
    override var atmosphere: CFVAtmosphere { .journey }

    override func viewDidLoad() {
        super.viewDidLoad()
        heading(CFVText("关卡册", "Level book"))
        column.addArrangedSubview(CFVProgressRibbon(
            title: String(format: CFVText("全部关卡 · 已完成 %d / 12", "All levels · Completed %d / 12"), app.progress.completed.count),
            detail: CFVText("每两关，遇见一位新的纸间伙伴", "A new paper companion every two levels"),
            completed: app.progress.completed.count, total: 12))
        let chapters = [CFVText("初次展开", "First folds"), CFVText("换个方向", "New directions"), CFVText("巧妙遮挡", "Clever overlaps")]
        let colors = [UIColor(hex: "DEE6D3"), UIColor(hex: "E6DFED"), UIColor(hex: "EBDCCB")]
        for chapter in 0..<3 {
            let card = UIStackView()
            card.axis = .vertical
            card.spacing = 10
            card.backgroundColor = colors[chapter].withAlphaComponent(0.85)
            card.layer.cornerRadius = 22
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.white.cgColor
            card.isLayoutMarginsRelativeArrangement = true
            card.layoutMargins = UIEdgeInsets(top: 15, left: 14, bottom: 12, right: 14)
            let header = UIStackView()
            header.spacing = 8
            let name = CFVTheme.label(String(format: "%02d  ·  %@", chapter + 1, chapters[chapter]), size: 18, serif: true)
            name.textAlignment = .left
            name.accessibilityTraits = .header
            header.addArrangedSubview(name)
            let count = (chapter * 4..<(chapter * 4 + 4)).filter { app.progress.completed.contains(app.repository.levels[$0].levelID) }.count
            let seal = CFVTheme.label("\(count) / 4", size: 12, color: CFVTheme.green)
            seal.setContentHuggingPriority(.required, for: .horizontal)
            header.addArrangedSubview(seal)
            card.addArrangedSubview(header)
            let route = CFVChapterRoute()
            for stop in 0..<4 {
                let index = chapter * 4 + stop
                let level = app.repository.levels[index]
                let completed = app.progress.completed.contains(level.levelID)
                let unlocked = index == 0 || app.progress.completed.contains(app.repository.levels[index - 1].levelID)
                let button = CFVTheme.button(String(format: "%02d", index + 1), symbol: completed ? "checkmark.circle.fill" : unlocked ? "circle" : "lock", primary: app.nextIndex == index) { [weak self] in
                    self?.app.begin(index, resume: self?.app.session?.levelID == level.levelID)
                }
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
                var configuration = button.configuration
                configuration?.imagePlacement = .top
                configuration?.imagePadding = 4
                configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
                if !unlocked { configuration?.baseForegroundColor = CFVTheme.muted }
                button.configuration = configuration
                button.accessibilityIdentifier = "level-\(index + 1)"
                button.accessibilityLabel = String(format: CFVText("第 %02d 关", "Level %02d"), index + 1) + ", " + CFVText(level.titleZH, level.titleEN)
                button.accessibilityValue = completed ? CFVText("已完成", "Completed") : unlocked ? CFVText("可游玩", "Available") : CFVText("尚未解锁", "Locked")
                route.row.addArrangedSubview(button)
            }
            card.addArrangedSubview(route)
            column.addArrangedSubview(card)
        }
        finish(docked: true)
    }
}

final class CFVCollectionController: CFVPageController {
    override var atmosphere: CFVAtmosphere { .collection }

    override func viewDidLoad() {
        super.viewDidLoad()
        heading(CFVText("生物图鉴", "Collection"))
        column.addArrangedSubview(CFVProgressRibbon(
            title: String(format: CFVText("已发现 %d / 6", "Discovered %d / 6"), app.unlockedCount),
            detail: CFVText("把每次相遇，收进纸间珍藏", "Keep every encounter in your paper collection"),
            completed: app.unlockedCount, total: 6, accent: UIColor(hex: "9483A5")))
        for rowIndex in 0..<3 {
            let row = UIStackView()
            row.distribution = .fillEqually
            row.spacing = 12
            for index in (rowIndex * 2)..<(rowIndex * 2 + 2) {
                let creature = app.repository.catalog.creatures[index]
                let stage = app.stage(creature)
                let card = UIStackView()
                card.axis = .vertical
                card.spacing = 6
                card.backgroundColor = UIColor(hex: stage == 2 ? "FCF9F0" : "EEEBDD")
                card.layer.cornerRadius = 20
                card.layer.borderWidth = 1.5
                card.layer.borderColor = (stage == 2 ? UIColor(hex: "C7BA92") : CFVTheme.line.withAlphaComponent(0.4)).cgColor
                card.layer.shadowColor = CFVTheme.ink.cgColor
                card.layer.shadowOpacity = 0.07
                card.layer.shadowOffset = CGSize(width: 0, height: 5)
                card.layer.shadowRadius = 9
                card.isLayoutMarginsRelativeArrangement = true
                card.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 10, right: 8)
                let serial = CFVTheme.label(String(format: "Nº %02d  ·  %@", index + 1, stage == 2 ? CFVText("珍藏", "COLLECTED") : CFVText("待发现", "UNDISCOVERED")), size: 10, color: stage == 2 ? UIColor(hex: "826D43") : CFVTheme.muted)
                card.addArrangedSubview(serial)
                let art = CFVCreatureView(id: creature.id, stage: stage)
                art.heightAnchor.constraint(equalToConstant: min(145, UIScreen.main.bounds.width * 0.36)).isActive = true
                card.addArrangedSubview(art)
                let button = CFVTheme.button(app.creatureName(creature)) { [weak self] in
                    guard let self else { return }
                    if stage == 2 { self.app.detail(creature) }
                    else { self.app.message(self.app.creatureName(creature), String(format: CFVText("完成第 %02d 关后解锁。制作进度 %d / 2。", "Unlock after level %02d. Making progress %d / 2."), creature.unlockLevel, stage)) }
                }
                button.accessibilityIdentifier = "creature-\(index)"
                card.addArrangedSubview(button)
                card.addArrangedSubview(CFVTheme.label(stage == 2 ? CFVText("已解锁", "Unfolded") : String(format: CFVText("完成第 %02d 关 · %d/2", "Level %02d · %d/2"), creature.unlockLevel, stage), size: 12, color: CFVTheme.muted))
                row.addArrangedSubview(card)
            }
            column.addArrangedSubview(row)
        }
        finish(docked: true)
    }
}

final class CFVCreatureController: CFVPageController {
    override var atmosphere: CFVAtmosphere { .collection }
    let creature: CFVCreature
    init(_ app: CFVAppCoordinator, creature: CFVCreature) { self.creature = creature; super.init(app) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        heading(app.creatureName(creature)) { [weak self] in self?.app.collection() }
        let illustration = art(creature, stage: 2, height: min(380, UIScreen.main.bounds.width))
        let descriptions = [
            "paper-butterfly": ("一对轻翼，从同一张纸中醒来。每一条折痕，都是飞行的起点。", "Two gentle wings awaken from one sheet. Every crease is the start of a flight."),
            "folded-bird": ("把一角留给天空。折起的羽翼，记得纸张最初的方向。", "Leave one corner to the sky. Folded wings remember where the paper began."),
            "paper-fish": ("游过留白的水面。换一个方向，远处的图案便在眼前相遇。", "Swimming through a sea of blank paper. A change of direction brings distant patterns together."),
            "paper-rabbit": ("竖起长耳，静听纸张的声音。轻轻一折，下一步就有了答案。", "Long ears listen for the rustle of paper. One gentle fold reveals the next step."),
            "paper-fox": ("藏起一点颜色，留下一点可能。聪明的选择，有时是暂时不动。", "Hide a little color, keep a possibility. Sometimes the clever choice is to wait."),
            "paper-deer": ("十二页之后，林间有了新的朋友。所有走过的折痕，都留在这双鹿角里。", "After twelve pages, a new friend stands in the forest. Every fold lives on in these antlers.")
        ]
        let description = descriptions[creature.id]!
        column.addArrangedSubview(CFVTheme.label(CFVText(description.0, description.1), size: 18, serif: true))
        column.addArrangedSubview(CFVTheme.label(CFVText("制作完成 · 2 / 2", "Complete · 2 / 2"), color: CFVTheme.muted))
        column.addArrangedSubview(CFVTheme.button(CFVText("再次展开", "Unfold again"), symbol: "play", primary: true) { illustration.replay(); CFVAudio.shared.play("fold") })
        finish()
        illustration.replay()
    }
}

final class CFVWinController: CFVPageController {
    override var atmosphere: CFVAtmosphere { .celebration }
    private var celebrated = false
    let level: CFVLevel
    let firstPresentation: Bool
    init(_ app: CFVAppCoordinator, level: CFVLevel, firstPresentation: Bool) { self.level = level; self.firstPresentation = firstPresentation; super.init(app) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        let index = app.repository.catalog.levelIDs.firstIndex(of: level.levelID)!
        let creature = app.creature(for: level)
        heading(CFVText("这一页，完成了", "A page, complete"))
        let illustration = art(creature, stage: app.stage(creature), height: min(320, UIScreen.main.bounds.height * 0.34), style: .reward)
        column.addArrangedSubview(CFVTheme.label(String(format: CFVText("第 %02d 关完成", "Level %02d complete"), index + 1), size: 25, serif: true))
        column.addArrangedSubview(CFVTheme.label(app.stage(creature) == 2 ? app.creatureName(creature) + " · " + CFVText("已解锁", "Unfolded") : app.creatureName(creature) + " · 1 / 2", size: 20))
        column.addArrangedSubview(CFVTheme.label(String(format: CFVText("使用步数 %d   ·   目标 %d / %d\n生物图鉴 %d / 6", "Moves used %d   ·   Targets %d / %d\nCollection %d / 6"), app.session?.actions.count ?? 0, level.targetCells.count, level.targetCells.count, app.unlockedCount), size: 16, color: CFVTheme.muted))
        if index < app.repository.levels.count - 1 {
            column.addArrangedSubview(CFVTheme.button(CFVText("下一关", "Next level"), symbol: "arrow.right", primary: true) { [weak self] in self?.app.begin(index + 1) })
        } else {
            column.addArrangedSubview(CFVTheme.label(CFVText("十二次相遇，六位纸间伙伴。\n谢谢你，为它们展开世界。", "Twelve encounters. Six paper companions.\nThank you for unfolding their world."), serif: true))
            column.addArrangedSubview(CFVTheme.button(CFVText("查看完整图鉴", "View complete collection"), symbol: "book", primary: true) { [weak self] in self?.app.collection() })
        }
        if app.stage(creature) == 2 {
            column.addArrangedSubview(CFVTheme.button(CFVText("查看生物", "View creature")) { [weak self] in self?.app.detail(creature) })
        }
        column.addArrangedSubview(CFVTheme.button(CFVText("返回关卡册", "Back to level book")) { [weak self] in self?.app.levels() })
        finish()
        if firstPresentation { illustration.replay(); CFVAudio.shared.play("win") }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard firstPresentation, !celebrated, !CFVSettings.shared.reduceMotion else { return }
        celebrated = true
        let celebration = CFVCelebrationView(frame: view.bounds)
        celebration.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(celebration)
        celebration.celebrate()
    }
}
