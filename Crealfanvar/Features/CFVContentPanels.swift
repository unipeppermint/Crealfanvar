import UIKit

/// A compact field-note card shared by the journey, collection and completion pages.
final class CFVNoteCard: UIStackView {
    init(kicker: String, title: String, body: String, accent: UIColor = CFVTheme.gold) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 10
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        backgroundColor = CFVTheme.card
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = accent.withAlphaComponent(0.3).cgColor
        let caption = CFVTheme.label(kicker, size: 11, color: accent)
        caption.textAlignment = .left
        addArrangedSubview(caption)
        let heading = CFVTheme.label(title, size: 20, serif: true)
        heading.textAlignment = .left
        heading.accessibilityTraits = .header
        addArrangedSubview(heading)
        if !body.isEmpty {
            let description = CFVTheme.label(body, size: 14, color: CFVTheme.muted)
            description.textAlignment = .left
            addArrangedSubview(description)
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func entry(symbol: String, title: String, detail: String, identifier: String? = nil) {
        let row = UIStackView()
        row.spacing = 12
        row.alignment = .top
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = CFVTheme.gold
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(icon)
        let text = UIStackView()
        text.axis = .vertical
        text.spacing = 3
        let name = CFVTheme.label(title, size: 15)
        name.textAlignment = .left
        let value = CFVTheme.label(detail, size: 12, color: CFVTheme.muted)
        value.textAlignment = .left
        value.accessibilityIdentifier = identifier
        text.addArrangedSubview(name)
        text.addArrangedSubview(value)
        row.addArrangedSubview(text)
        addArrangedSubview(row)
    }
}

struct CFVCreatureProfile {
    let trait: String
    let note: String
    let greeting: String
    let light: CFVGardenLight

    static func forID(_ id: String) -> Self {
        switch id {
        case "paper-butterfly":
            return Self(trait: CFVText("微风旅人", "A breeze traveler"),
                        note: CFVText("宽阔的双翼藏着对称的折面。把它放在花园一侧，像刚从纸树旁轻轻飞过。", "Wide wings hold mirrored folds. Place it beside a paper tree, as if it has just drifted past."),
                        greeting: CFVText("轻轻扑翼", "A gentle flutter"), light: .amber)
        case "folded-bird":
            return Self(trait: CFVText("天空来信", "A letter from the sky"),
                        note: CFVText("向上扬起的羽翼，给安静的森林留下一点动势。试着让它与纸蝶一起迎接暖光。", "Raised wings bring movement to the quiet forest. Pair it with the butterfly in amber light."),
                        greeting: CFVText("振翅跃起", "A winged lift"), light: .amber)
        case "paper-fish":
            return Self(trait: CFVText("涟漪收藏家", "A ripple collector"),
                        note: CFVText("层叠的鱼鳍像散开的纸扇。月夜的冷光会衬出它的轮廓，池畔则是另一种搭配。", "Layered fins open like paper fans. Moonlight frames its silhouette; the pond offers another setting."),
                        greeting: CFVText("悠悠摆动", "A gentle swish"), light: .moon)
        case "paper-rabbit":
            return Self(trait: CFVText("林间倾听者", "A forest listener"),
                        note: CFVText("长耳与小小的折角，是它最醒目的轮廓。留出一点空位，看它蹦两下，再安静落回纸面。", "Long ears and small folded corners shape its silhouette. Leave a little room for two hops and a quiet landing."),
                        greeting: CFVText("轻快双跳", "Two little hops"), light: .dusk)
        case "paper-fox":
            return Self(trait: CFVText("暮色漫步者", "A dusk wanderer"),
                        note: CFVText("暖色折面与尖尖的耳朵，让它在深色森林里格外醒目。和纸鹿并排，像两位相遇的旅人。", "Warm facets and pointed ears stand out in the dark forest. Beside the deer, it looks like one traveler meeting another."),
                        greeting: CFVText("侧身探望", "A curious peek"), light: .dusk)
        default:
            return Self(trait: CFVText("折痕守望者", "A keeper of folds"),
                        note: CFVText("细长的腿与分叉的纸角，让轮廓舒展而安静。把它放在中央，让小伙伴围在两旁。", "Slender legs and branching paper antlers create a quiet silhouette. Place it in the center with friends on either side."),
                        greeting: CFVText("轻轻俯身", "A quiet bow"), light: .moon)
        }
    }
}

enum CFVChapterNotes {
    static func text(_ index: Int) -> String {
        let notes = [
            CFVText("从一次交换开始，发现折痕另一侧的相遇。", "Start with a swap and discover what lies across a fold."),
            CFVText("换个方向观察，让交换与折叠接力。", "Look from another side and connect swaps with folds."),
            CFVText("学会留下空白，也学会保留下一步。", "Read the empty spaces and keep a move for later."),
            CFVText("比较窄边与宽边，用四步安排新的相遇。", "Compare narrow and wider folds across four moves."),
            CFVText("五步之间，留意那些看似顺手的开局。", "Across five moves, question the tempting first match."),
            CFVText("用六步串起远处的目标，收下森林最后的礼物。", "Connect distant targets in six moves and find the final forest gift.")
        ]
        return notes[min(notes.count - 1, max(0, index))]
    }
}

extension CFVAppCoordinator {
    func giftCabinet() -> CFVNoteCard {
        let earned = [16, 20, 24].filter { progress.completed.contains(String(format: "level-%02d", $0)) }.count
        let card = CFVNoteCard(kicker: CFVText("森林纪念", "FOREST KEEPSAKES"),
                               title: String(format: CFVText("花园礼物 · %d / 3", "Garden gifts · %d / 3"), earned),
                               body: CFVText("挑战留下的纪念，也能成为花园的一部分。", "Keepsakes from your journey become part of your garden."))
        card.accessibilityIdentifier = "gift-cabinet"
        for (level, symbol) in [(16, "lamp.desk"), (20, "water.waves"), (24, "star")] {
            let unlocked = progress.completed.contains(String(format: "level-%02d", level))
            let detail = unlocked
                ? CFVText("已收入收藏 · 可在花园中布置", "Collected · Ready to arrange in the garden")
                : String(format: CFVText("完成第 %d 关，把它带回花园", "Complete level %d to bring it to the garden"), level)
            card.entry(symbol: symbol, title: CFVGardenGift.forLevel(level)!, detail: detail, identifier: "gift-status-\(level)")
        }
        return card
    }
}
