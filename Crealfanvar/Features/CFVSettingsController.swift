import UIKit

final class CFVSettingsController: UITableViewController {
    private let app: CFVAppCoordinator
    init(_ app: CFVAppCoordinator) { self.app = app; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.overrideUserInterfaceStyle = .light
        view.backgroundColor = CFVTheme.paper
        title = CFVText("设置", "Settings")
        configureNavigation()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = CFVTheme.ink
    }

    private func configureNavigation() {
        title = CFVText("设置", "Settings")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: CFVText("返回", "Back"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "settings-back"
    }

    @objc private func close() {
        navigationController?.popViewController(animated: true)
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 4 : section == 1 ? 2 : 3 }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 { return CFVText("动画默认跟随系统；开启后始终减少动态效果。声音遵循静音模式。", "Motion follows the system by default. Enable to always reduce motion. Audio respects silent mode.") }
        if section == 2 { return "Paperkin · 1.0 (1)\n" + CFVText("免费离线 · 无账号 · 无广告 · 无内购", "Free and offline · No account, ads or purchases") }
        return nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = CFVTheme.card
        cell.textLabel?.font = CFVTheme.font(17)
        cell.textLabel?.textColor = CFVTheme.ink
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = CFVTheme.muted
        let settings = CFVSettings.shared
        if indexPath.section == 0 {
            let names = [CFVText("背景音乐", "Music"), CFVText("音效", "Sound effects"), CFVText("触感", "Haptics"), CFVText("减少动态效果", "Reduce motion")]
            cell.textLabel?.text = names[indexPath.row]
            let toggle = UISwitch()
            toggle.onTintColor = CFVTheme.green
            toggle.isOn = [settings.music, settings.sound, settings.haptics, settings.motionReduced][indexPath.row]
            toggle.accessibilityLabel = names[indexPath.row]
            toggle.addAction(UIAction { [weak toggle] _ in
                guard let toggle else { return }
                switch indexPath.row {
                case 0: settings.music = toggle.isOn
                case 1: settings.sound = toggle.isOn
                case 2: settings.haptics = toggle.isOn
                default: settings.motionReduced = toggle.isOn
                }
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        } else if indexPath.section == 1 {
            cell.textLabel?.text = indexPath.row == 0 ? CFVText("语言", "Language") : CFVText("玩法帮助", "How to play")
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.textLabel?.text = [CFVText("隐私说明", "Privacy"), CFVText("支持", "Support"), CFVText("本地数据", "Local data")][indexPath.row]
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 && indexPath.row == 0 {
            let alert = UIAlertController(title: CFVText("语言", "Language"), message: nil, preferredStyle: .actionSheet)
            for (code, name) in [("system", CFVText("跟随系统", "System")), ("zh-Hans", "简体中文"), ("en", "English")] {
                alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                    CFVSettings.shared.language = code
                    guard let self else { return }
                    self.configureNavigation()
                    self.tableView.reloadData()
                    self.app.refreshSettingsOrigin()
                })
            }
            alert.addAction(UIAlertAction(title: CFVText("取消", "Cancel"), style: .cancel))
            present(alert, animated: true)
        } else if indexPath.section == 1 { navigationController?.pushViewController(CFVHelpController(), animated: true) }
        else if indexPath.section == 2 {
            let title = [CFVText("隐私说明", "Privacy"), CFVText("支持", "Support"), CFVText("本地数据", "Local data")][indexPath.row]
            let privacy = CFVText("关卡、收藏和设置保存在本设备。本应用不创建账号，不包含广告或分析 SDK，不上传游玩数据。删除应用可能删除本地进度。\n\n公开隐私政策地址尚待开发者配置，发布前必须补齐。", "Levels, collection and settings are stored on this device. The app has no accounts, advertising or analytics SDKs and does not upload gameplay data. Deleting the app may delete local progress.\n\nThe developer must configure a public privacy policy URL before release.")
            let support = CFVText("遇到困难时可使用提示、撤销或重新开始。存档异常时会优先尝试备份，已完成记录独立保存。\n\n支持联系方式与公开支持地址尚待开发者提供，发布前必须补齐。", "Use Hint, Undo or Restart when stuck. If a save is damaged, the app tries its backup. Completion records are stored separately.\n\nThe developer must provide a support contact and public support URL before release.")
            let local = CFVText("只保存一个活动对局。进入其他关卡会先询问是否替换。本机收藏不会因重玩或撤销减少。首版不提供跨设备同步。", "One active game is saved. Starting another level asks before replacing it. Replaying or undoing never removes collected creatures. Cross-device sync is not available in this release.")
            let controller = CFVTextController(title: title, body: indexPath.row == 0 ? privacy : indexPath.row == 1 ? support : local)
            let key = indexPath.row == 0 ? "CFVPrivacyURL" : "CFVSupportURL"
            if indexPath.row < 2, let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: value), url.scheme == "https" {
                controller.externalURL = url
            }
            navigationController?.pushViewController(controller, animated: true)
        }
    }
}

class CFVTextController: UIViewController {
    let body: String
    var externalURL: URL?
    init(title: String, body: String) { self.body = body; super.init(nibName: nil, bundle: nil); self.title = title }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CFVTheme.paper
        view.overrideUserInterfaceStyle = .light
        let text = UITextView()
        text.backgroundColor = .clear
        text.isEditable = false
        text.font = CFVTheme.font(18)
        text.adjustsFontForContentSizeCategory = true
        text.textColor = CFVTheme.ink
        text.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 32, right: 20)
        text.text = body + (externalURL.map { "\n\n" + $0.absoluteString } ?? "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.dataDetectorTypes = .link
        view.addSubview(text)
        NSLayoutConstraint.activate([text.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), text.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), text.leadingAnchor.constraint(equalTo: view.leadingAnchor), text.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
    }
}

final class CFVHelpController: UIViewController {
    private var index = 0
    private let content = UIStackView()
    private let pageControl = UIPageControl()
    private var previous: UIButton!
    private var nextButton: UIButton!
    private var cards: [(String, String, String)] {
        [
            (CFVText("01 · 交换", "01 · Swap"), CFVText("点选一枚棋子，再点上下左右相邻的棋子，也可滑动交换。三个及以上同图案横向或纵向连续才有效。无效交换不扣步。", "Select a tile, then an adjacent neighbor, or swipe to swap. A horizontal or vertical line of at least three matching patterns is required. Invalid swaps cost no moves."), "arrow.left.arrow.right"),
            (CFVText("02 · 折叠", "02 · Fold"), CFVText("点按折痕按钮或虚线，或者从纸面边缘向内拖动。先检查预览，再确认。取消不扣步，没有三连时不能确认。每次只折一个面。", "Tap a crease button or dashed line, or drag inward from the paper edge. Inspect the preview, then confirm. Cancel costs no moves. A fold without a match cannot be confirmed. Fold one face at a time."), "map"),
            (CFVText("03 · 遮挡", "03 · Overlap"), CFVText("移动纸面在上，只匹配表面图案。被盖住的棋子保留。空白纸面也遮挡下层。结算后自动展开，没有掉落、补充或二次连锁。", "Moving paper lies on top. Only visible patterns match; covered tiles remain. Even blank paper covers the lower layer. The sheet unfolds after each move. Tiles never fall, refill or chain after unfolding."), "square.3.layers.3d"),
            (CFVText("04 · 菱形目标", "04 · Diamond targets"), CFVText("空心菱形跟随棋子移动。消除所有目标即可完成，即使恰好用完最后一步。提示先给方向，再显示操作。撤销恢复步数和目标。\n\nVoiceOver 可朗读行列、图案和目标，双击选择相邻棋子，或使用自定义交换操作。折痕按钮替代拖动。设置中可调整声音、触感与动画。", "Hollow diamonds travel with their tiles. Clear every target to win, even on the last move. Hints first give a direction, then reveal an action. Undo restores moves and targets.\n\nVoiceOver reads rows, columns, patterns and targets. Double-tap neighbors or use custom swap actions. Crease buttons replace dragging. Adjust sound, haptics and motion in Settings."), "diamond")
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CFVTheme.paper
        view.overrideUserInterfaceStyle = .light
        title = CFVText("玩法帮助", "How to play")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: CFVText("完成", "Done"), style: .done, target: self, action: #selector(done))
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 24
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        content.backgroundColor = CFVTheme.card
        content.layer.cornerRadius = 20
        view.addSubview(scroll)
        scroll.addSubview(content)
        let bottom = UIStackView()
        bottom.axis = .vertical
        bottom.spacing = 12
        bottom.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = 4
        pageControl.currentPageIndicatorTintColor = CFVTheme.green
        pageControl.pageIndicatorTintColor = CFVTheme.line
        pageControl.addTarget(self, action: #selector(pageChanged), for: .valueChanged)
        bottom.addArrangedSubview(pageControl)
        let buttons = UIStackView()
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        previous = CFVTheme.button(CFVText("上一页", "Previous"), symbol: "chevron.left") { [weak self] in self?.change(-1) }
        nextButton = CFVTheme.button(CFVText("下一页", "Next"), symbol: "chevron.right", primary: true) { [weak self] in self?.change(1) }
        buttons.addArrangedSubview(previous)
        buttons.addArrangedSubview(nextButton)
        bottom.addArrangedSubview(buttons)
        view.addSubview(bottom)
        NSLayoutConstraint.activate([
            bottom.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bottom.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), bottom.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), scroll.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        showCard()
    }

    private func change(_ delta: Int) { index = min(3, max(0, index + delta)); showCard() }
    @objc private func pageChanged() { index = pageControl.currentPage; showCard() }
    private func showCard() {
        content.arrangedSubviews.forEach { content.removeArrangedSubview($0); $0.removeFromSuperview() }
        let card = cards[index]
        let symbol = UIImageView(image: UIImage(systemName: card.2, withConfiguration: UIImage.SymbolConfiguration(pointSize: 58)))
        symbol.contentMode = .scaleAspectFit
        symbol.tintColor = CFVTheme.green
        symbol.heightAnchor.constraint(equalToConstant: 88).isActive = true
        content.addArrangedSubview(symbol)
        let title = CFVTheme.label(card.0, size: 26, serif: true)
        title.accessibilityTraits = .header
        content.addArrangedSubview(title)
        let body = CFVTheme.label(card.1, size: 18)
        body.textAlignment = .left
        content.addArrangedSubview(body)
        previous.isEnabled = index > 0
        nextButton.isEnabled = index < 3
        pageControl.currentPage = index
        UIAccessibility.post(notification: .screenChanged, argument: title)
    }
    @objc private func done() {
        if navigationController?.viewControllers.first === self {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}
