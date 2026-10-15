import UIKit

nonisolated final class CFVCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func cancel() { lock.lock(); value = true; lock.unlock() }
}

final class CFVGameController: UIViewController {
    let app: CFVAppCoordinator
    let level: CFVLevel
    private let board = CFVBoardView()
    private let hud = CFVTheme.label("", size: 19)
    private let messageLabel = CFVTheme.label("", size: 13, color: CFVTheme.muted)
    private let foldRow = UIStackView()
    private let tools = UIStackView()
    private let column = UIStackView()
    private var undoButton: UIButton!
    private var hintButton: UIButton!
    private var selected: Int?
    private var preview: CFVFold?
    private var highlights = Set<Int>()
    private var inputLocked = false
    private var cancellation: CFVCancellation?
    private var pendingHint: CFVAction?
    private var needsPause = false
    private var presentedOutcome = false
        private var introShown = false
    private var state: CFVState { app.session!.state }

    init(_ app: CFVAppCoordinator, level: CFVLevel) {
        self.app = app
        self.level = level
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        let paper = CFVPaperView()
        paper.atmosphere = .play
        view = paper
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.overrideUserInterfaceStyle = .light
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        let compact = UIScreen.main.bounds.height < 740
        if compact { column.spacing = 2 }
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            column.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            column.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        let header = UIStackView()
        header.spacing = 8
        let back = CFVTheme.button("", symbol: "chevron.left") { [weak self] in self?.leave() }
        back.accessibilityLabel = CFVText("返回关卡册", "Back to level book")
        back.widthAnchor.constraint(equalToConstant: 48).isActive = true
        header.addArrangedSubview(back)
        let number = app.repository.catalog.levelIDs.firstIndex(of: level.levelID)! + 1
        let title = CFVTheme.label(String(format: CFVText("第 %02d 关", "Level %02d"), number), size: 23, serif: true)
        title.accessibilityTraits = .header
        header.addArrangedSubview(title)
        let pause = CFVTheme.button("", symbol: "pause") { [weak self] in self?.pause() }
        pause.accessibilityLabel = CFVText("暂停", "Pause")
        pause.accessibilityIdentifier = "pause"
        pause.widthAnchor.constraint(equalToConstant: 48).isActive = true
        header.addArrangedSubview(pause)
        column.addArrangedSubview(header)
        hud.accessibilityIdentifier = "game-hud"
        hud.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        hud.layer.cornerRadius = 12
        hud.clipsToBounds = true
        hud.heightAnchor.constraint(greaterThanOrEqualToConstant: compact ? 28 : 38).isActive = true
        if UIScreen.main.bounds.height > 700 {
            let hudRow = UIStackView()
            hudRow.spacing = 12
            let creature = app.creature(for: level)
            let illustration = CFVCreatureView(id: creature.id, stage: app.stage(creature))
            illustration.widthAnchor.constraint(equalToConstant: 72).isActive = true
            illustration.heightAnchor.constraint(equalToConstant: 64).isActive = true
            hudRow.addArrangedSubview(illustration)
            hudRow.addArrangedSubview(hud)
            column.addArrangedSubview(hudRow)
        } else { column.addArrangedSubview(hud) }
        if !compact {
            messageLabel.numberOfLines = 3
            messageLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
            column.addArrangedSubview(messageLabel)
        }
        let boardHolder = UIView()
        boardHolder.backgroundColor = UIColor(hex: "E3D9C3")
        boardHolder.layer.cornerRadius = 10
        boardHolder.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        boardHolder.layer.borderWidth = 2
        board.translatesAutoresizingMaskIntoConstraints = false
        boardHolder.addSubview(board)
        column.addArrangedSubview(boardHolder)
        let size = board.widthAnchor.constraint(equalTo: column.widthAnchor)
        size.priority = .defaultHigh
        NSLayoutConstraint.activate([
            board.centerXAnchor.constraint(equalTo: boardHolder.centerXAnchor),
            board.topAnchor.constraint(equalTo: boardHolder.topAnchor),
            board.bottomAnchor.constraint(equalTo: boardHolder.bottomAnchor),
            board.heightAnchor.constraint(equalTo: board.widthAnchor),
            board.widthAnchor.constraint(lessThanOrEqualTo: column.widthAnchor),
            board.widthAnchor.constraint(greaterThanOrEqualToConstant: 264),
            board.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: compact ? -220 : -290), size
        ])
        foldRow.axis = .horizontal
        foldRow.spacing = 8
        foldRow.distribution = .fillEqually
        column.addArrangedSubview(foldRow)
        tools.axis = .horizontal
        tools.spacing = 8
        tools.distribution = .fillEqually
        undoButton = CFVTheme.button(CFVText("撤销", "Undo"), symbol: "arrow.uturn.backward") { [weak self] in self?.undo() }
        undoButton.accessibilityIdentifier = "undo"
        hintButton = CFVTheme.button(CFVText("提示", "Hint"), symbol: "lightbulb") { [weak self] in self?.hint() }
        hintButton.accessibilityIdentifier = "hint"
        tools.addArrangedSubview(undoButton)
        tools.addArrangedSubview(hintButton)
        let help = CFVTheme.button(CFVText("帮助", "Help"), symbol: "questionmark.circle") { [weak self] in
            guard let self else { return }
            self.app.help(from: self)
        }
        tools.addArrangedSubview(help)
        column.addArrangedSubview(tools)
        board.onCell = { [weak self] in self?.select($0) }
        board.onSwap = { [weak self] in self?.perform(.swap($0, $1)) }
        board.onFold = { [weak self] in self?.showPreview($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
        messageLabel.text = CFVText(level.purposeZH, level.purposeEN)
        if state.revision == 0 { highlights = Set(level.tutorialCells) }
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if needsPause {
            pause()
            return
        }
        if !introShown && state.revision == 0 && !app.progress.seenTutorials.contains(level.levelID) {
            introShown = true
            let alert = UIAlertController(title: CFVText(level.titleZH, level.titleEN), message: CFVText(level.purposeZH, level.purposeEN), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: CFVText("试试看", "Let's try"), style: .default) { [weak self] _ in
                guard let self else { return }
                var progress = self.app.progress
                progress.seenTutorials.insert(self.level.levelID)
                do { try self.app.store.saveProgress(progress); self.app.progress = progress }
                catch { self.app.saveError(error) }
            })
            present(alert, animated: true)
        } else { handleOutcome() }
    }

    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); cancelHint() }
    deinit { cancellation?.cancel(); NotificationCenter.default.removeObserver(self) }

    private func render() {
        hud.text = String(format: CFVText("◇ 目标 %d/%d     剩余 %d 步", "◇ Targets %d/%d     Moves left: %d"), level.targetCells.count - state.remainingTargets, level.targetCells.count, state.remainingMoves)
        board.render(level: level, state: state, preview: preview, selection: selected, highlights: highlights)
        board.isUserInteractionEnabled = !inputLocked && preview == nil && state.outcome == .playing
        undoButton.isEnabled = !inputLocked && (preview != nil || !(app.session?.history.isEmpty ?? true)) && state.outcome != .won
        undoButton.accessibilityHint = undoButton.isEnabled ? "" : CFVText("尚无可撤销操作", "No move to undo yet")
        hintButton.isEnabled = !inputLocked && preview == nil && state.outcome == .playing
        foldRow.arrangedSubviews.forEach { foldRow.removeArrangedSubview($0); $0.removeFromSuperview() }
        if let preview {
            let matches = CFVEngine.matches(state, projection: CFVEngine.projection(preview))
            let targets = state.tiles.compactMap { $0 }.filter { $0.isTarget && matches.contains($0.id) }.count
            let text = matches.isEmpty ? CFVText("当前折法未形成三连", "This fold makes no match") : String(format: CFVText("可消除 %d 枚，其中目标 %d 枚\n上层纸面遮挡下层，空白也遮挡", "Clear %d tiles, including %d targets\nTop paper covers the lower layer, even when blank"), matches.count, targets)
            messageLabel.text = text
            UIAccessibility.post(notification: .announcement, argument: text)
            let confirmationTitle = (matches.isEmpty ? CFVText("未形成三连", "No match") : CFVText("确认折叠", "Confirm Fold")) + (UIScreen.main.bounds.height < 740 ? "\n" + String(format: CFVText("%d 枚 · 目标 %d", "Tiles: %d · targets: %d"), matches.count, targets) : "")
            let confirm = CFVTheme.button(confirmationTitle, primary: true) { [weak self] in self?.perform(.fold(preview.creaseID)) }
            confirm.isEnabled = !matches.isEmpty && !inputLocked
            confirm.accessibilityIdentifier = "confirm-fold"
            confirm.accessibilityHint = text
            foldRow.addArrangedSubview(confirm)
            let cancel = CFVTheme.button(CFVText("取消", "Cancel")) { [weak self] in self?.cancelPreview() }
            cancel.isEnabled = !inputLocked
            cancel.accessibilityIdentifier = "cancel-fold"
            foldRow.addArrangedSubview(cancel)
        } else if level.folds.isEmpty {
            let label = CFVTheme.label(CFVText("点选两格，或滑动交换", "Tap two neighbors, or swipe to swap"), size: 14, color: CFVTheme.muted)
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
            foldRow.addArrangedSubview(label)
        } else {
            for fold in level.folds {
                let button = CFVTheme.button(foldTitle(fold), symbol: "map", primary: pendingHint?.creaseID == fold.creaseID) { [weak self] in self?.showPreview(fold) }
                button.isEnabled = !inputLocked && state.outcome == .playing
                button.accessibilityIdentifier = "fold-" + fold.creaseID
                button.accessibilityHint = CFVText("预览折痕，不扣步数", "Preview this crease without spending a move")
                foldRow.addArrangedSubview(button)
            }
        }
    }

    private func foldTitle(_ fold: CFVFold) -> String {
        let width = ["left", "top"].contains(fold.movingSide) ? fold.boundary : 6 - fold.boundary
        switch fold.movingSide {
        case "left": return String(format: CFVText("左侧 %d 列", "Left %d cols"), width)
        case "right": return String(format: CFVText("右侧 %d 列", "Right %d cols"), width)
        case "top": return String(format: CFVText("上方 %d 行", "Top %d rows"), width)
        default: return String(format: CFVText("下方 %d 行", "Bottom %d rows"), width)
        }
    }

    private func select(_ cell: Int) {
        guard !inputLocked, preview == nil, state.outcome == .playing else { return }
        if let selected, selected != cell {
            if abs(selected / 6 - cell / 6) + abs(selected % 6 - cell % 6) == 1 { perform(.swap(selected, cell)); return }
        }
        guard state.tiles[cell] != nil else {
            announce(CFVText("空白纸格不能交换，仍会遮挡下层。", "Blank paper cannot be swapped, and still covers the lower layer."))
            return
        }
        selected = selected == cell ? nil : cell
        CFVAudio.shared.play("select")
        render()
    }

    private func showPreview(_ fold: CFVFold) {
        guard !inputLocked, preview == nil, state.outcome == .playing else { return }
        cancelHint()
        selected = nil
        highlights.removeAll()
        inputLocked = true
        board.isUserInteractionEnabled = false
        CFVAudio.shared.play("fold")
        board.animateFold(fold) { [weak self] in
            guard let self else { return }
            self.inputLocked = false
            if !self.needsPause { self.preview = fold }
            self.render()
        }
    }

    private func cancelPreview() {
        guard !inputLocked, let fold = preview else { return }
        inputLocked = true
        render()
        board.animateUnfold(fold, state: state) { [weak self] in
            guard let self else { return }
            self.preview = nil
            self.inputLocked = false
            self.announce(CFVText("已取消预览，没有扣步。", "Preview cancelled. No move spent."))
            self.render()
        }
    }

    private func perform(_ action: CFVAction) {
        guard !inputLocked, state.outcome == .playing, (preview == nil || action.type == "fold") else { return }
        guard let turn = CFVEngine.apply(level, state, action) else {
            board.shake()
            selected = nil
            announce(CFVText("交换后没有形成三连，步数不变。", "That swap makes no match. No move spent."))
            if UIScreen.main.bounds.height < 740 {
                app.message(CFVText("无效交换", "Invalid swap"), messageLabel.text ?? "")
            }
            render()
            return
        }
        cancelHint()
        let before = state
        var candidate = app.session!
        candidate.commit(turn, action: action)
        inputLocked = true
        do {
            try app.commit(candidate)
        } catch {
            inputLocked = false
            preview = nil
            render()
            app.saveError(error, retry: { [weak self] in
                guard let self else { return }
                if self.state.outcome == .won { self.app.showWin(self.level) }
                else { self.perform(action) }
            })
            return
        }
        selected = nil
        highlights.removeAll()
        board.isUserInteractionEnabled = false
        CFVAudio.shared.play(action.type == "fold" ? "fold" : "swap")
        board.animateTurn(action, before: before, after: turn.state, removedIDs: turn.removedIDs) { [weak self] in
            guard let self else { return }
            self.preview = nil
            self.inputLocked = false
            CFVAudio.shared.play("match")
            self.announce(CFVText("纸面已展开。目标进度已保存。", "Paper unfolded. Target progress saved."))
            self.render()
            if !self.needsPause { self.handleOutcome() }
        }
    }

    private func undo() {
        guard !inputLocked else { return }
        if preview != nil { cancelPreview(); return }
        guard !(app.session?.history.isEmpty ?? true), state.outcome != .won else { return }
        cancelHint()
        var candidate = app.session!
        candidate.undo()
        do {
            try app.commit(candidate)
            selected = nil
            highlights.removeAll()
            presentedOutcome = false
            announce(CFVText("已恢复上一步，步数与目标一同恢复。", "Previous move restored, including moves and targets."))
            render()
        } catch { app.saveError(error) }
    }

    private func hint() {
        guard !inputLocked, preview == nil else { return }
        if let action = pendingHint {
            highlights = Set([action.first, action.second].compactMap { $0 })
            announce(action.type == "fold" ? CFVText("高亮折痕已准备好。点按预览，再决定是否确认。", "The highlighted crease is ready. Preview it before confirming.") : String(format: CFVText("交换第 %d 行 %d 列与第 %d 行 %d 列。", "Swap row %d column %d with row %d column %d."), action.first! / 6 + 1, action.first! % 6 + 1, action.second! / 6 + 1, action.second! % 6 + 1))
            render()
            if UIScreen.main.bounds.height < 740 {
                app.message(CFVText("下一步", "Next move"), messageLabel.text ?? "")
            }
            return
        }
        cancellation?.cancel()
        let token = CFVCancellation()
        cancellation = token
        let capturedState = state
        let capturedLevel = level
        hintButton.isEnabled = false
        announce(CFVText("正在推演…", "Thinking…"))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CFVHintSolver.solve(level: capturedLevel, state: capturedState, cancelled: { token.cancelled })
            DispatchQueue.main.async {
                guard let self, !token.cancelled, self.state.revision == capturedState.revision, self.view.window != nil else { return }
                self.hintButton.isEnabled = true
                switch result {
                case .foundPath(let path):
                    guard let action = path.first else { return }
                    self.pendingHint = action
                    let direction = action.type == "fold" ? CFVText("下一步试试折叠。", "Try a fold next.") : CFVText("下一步先交换。", "Try a swap next.")
                    self.announce(direction)
                    let alert = UIAlertController(title: CFVText("提示", "Hint"), message: direction, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: CFVText("显示操作", "Show move"), style: .default) { [weak self] _ in self?.hint() })
                    alert.addAction(UIAlertAction(title: CFVText("稍后再看", "Later"), style: .cancel))
                    self.present(alert, animated: true)
                case .provenNoSolution: self.app.message(CFVText("试试撤销", "Try Undo"), CFVText("这条路线无法在剩余步数内完成，试试撤销。", "This route cannot finish in the remaining moves. Try Undo."))
                case .budgetExceeded: self.app.message(CFVText("暂未找到提示", "No hint found yet"), CFVText("暂未找到提示，可以继续尝试或撤销。", "No hint found yet. Keep exploring or try Undo."))
                case .cancelled: break
                }
            }
        }
    }

    private func cancelHint() { cancellation?.cancel(); cancellation = nil; pendingHint = nil; hintButton?.isEnabled = true }
    private func announce(_ text: String) { messageLabel.text = text; UIAccessibility.post(notification: .announcement, argument: text) }

    private func handleOutcome() {
        guard presentedViewController == nil, !presentedOutcome else { return }
        if state.outcome == .won { presentedOutcome = true; app.showWin(level); return }
        guard state.outcome != .playing else { return }
        presentedOutcome = true
        CFVAudio.shared.play("fail")
        let reason = state.outcome == .outOfMoves ? CFVText("步数用完了", "No moves left") : CFVText("当前没有可用操作", "No legal moves remain")
        let alert = UIAlertController(title: reason, message: String(format: CFVText("还有 %d 枚目标。可以免费撤销或重玩。", "%d targets remain. Undo or restart for free."), state.remainingTargets), preferredStyle: .alert)
        if !(app.session?.history.isEmpty ?? true) { alert.addAction(UIAlertAction(title: CFVText("撤销上一步", "Undo last move"), style: .default) { [weak self] _ in self?.undo() }) }
        alert.addAction(UIAlertAction(title: CFVText("重新开始", "Restart"), style: .default) { [weak self] _ in self?.needsPause = false; self?.restart() })
        alert.addAction(UIAlertAction(title: CFVText("返回关卡册", "Back to level book"), style: .cancel) { [weak self] _ in self?.leave() })
        present(alert, animated: true)
    }

    private func restart() {
        app.confirm(CFVText("重新开始本关？", "Restart this level?"), CFVText("本局操作将清空，已完成关卡和图鉴会保留。", "Current moves will be cleared. Completed levels and creatures are kept.")) { [weak self] in
            guard let self else { return }
            self.app.startFresh(self.level)
        }
    }

    private func leave() {
        cancelHint()
        board.cancelAnimation()
        preview = nil
        app.levels()
    }

    private func pause() {
        guard presentedViewController == nil else { return }
        needsPause = true
        board.cancelAnimation()
        inputLocked = false
        cancelHint()
        preview = nil
        selected = nil
        render()
        let alert = UIAlertController(title: CFVText("暂停", "Paused"), message: CFVText("已提交的动作会自动保存。", "Committed moves are saved automatically."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: CFVText("继续", "Continue"), style: .default) { [weak self] _ in self?.needsPause = false; self?.handleOutcome() })
        alert.addAction(UIAlertAction(title: CFVText("重新开始", "Restart"), style: .default) { [weak self] _ in self?.needsPause = false; self?.restart() })
        if state.outcome == .playing {
            alert.addAction(UIAlertAction(title: CFVText("玩法帮助", "How to play"), style: .default) { [weak self] _ in
                guard let self else { return }
                self.needsPause = false
                self.app.help(from: self)
            })
            alert.addAction(UIAlertAction(title: CFVText("设置", "Settings"), style: .default) { [weak self] _ in
                self?.needsPause = false
                self?.app.settings()
            })
        }
        alert.addAction(UIAlertAction(title: CFVText("返回关卡册", "Back to level book"), style: .cancel) { [weak self] _ in self?.leave() })
        present(alert, animated: true)
    }

    @objc private func background() {
        cancelHint()
        needsPause = true
        preview = nil
        selected = nil
        board.cancelAnimation()
        board.layer.removeAllAnimations()
        inputLocked = false
        render()
    }

    @objc private func foreground() {
        guard needsPause, view.window != nil else { return }
        if presentedViewController != nil {
            dismiss(animated: false) { [weak self] in self?.pause() }
        } else { pause() }
    }
}
