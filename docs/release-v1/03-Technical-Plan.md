# 折叠生物技术方案

版本：1.0 规划基线 修订2  
日期：2026年10月15日

首版采用 Swift、UIKit、Core Animation 和纯 Swift 规则引擎。目标是实现完整离线应用，保证折叠预览、消除结果、撤销和存档一致。棋盘只包含 36 个格子，优先使用系统框架，无第三方运行时依赖。

内容规模为 12 关和 6 种生物，关卡册为一个页面。每两关对应一种生物，解锁节点为 02、04、06、08、10、12；学习阶段只用于配置难度。棋盘仍为 6×6，不能把关卡数量变化误改为棋盘格子数量变化。

## 工程基线

当前项目为 Crealfanvar，入口是 AppDelegate、SceneDelegate 和 Storyboard，业务 ViewController 为空。App Target 的最低系统版本为 iOS 15.0，Swift 语言模式为 5.0，设备族为 iPhone，竖屏。

工程级配置另有 iOS 26.5 的设置，App Target 当前显式覆盖为 15.0。开发时用实际构建设置和设备运行结果确认生效值，不根据某一行配置推断全部目标。Swift 5.0 是语言模式，不代表当前编译器版本。

沿用现有入口并由现有根 ViewController 承载协调器，新业务页面使用代码布局。首版不需要修改 Bundle ID、签名团队、发布配置或新增联网权限。发布 SDK、证书和描述文件在发布阶段核验，不在文档整理阶段调整。

## 模块职责

| 模块 | 责任 | 不承担的责任 |
| --- | --- | --- |
| AppCoordinator | 主页面导航、局内流程、恢复入口 | 不判断匹配 |
| GameViewController | 收集输入、显示 HUD、协调预览和动画 | 不直接修改棋盘数组 |
| BoardView | 绘制格子和棋子、命中测试、无障碍元素 | 不计算胜负 |
| FoldAnimator | 纸面层次、透视、背面、阴影、取消动画 | 不从角度反推规则 |
| GameEngine | 验证动作、投影、匹配、目标、步数、状态输出 | 不引用 UIKit |
| HintSolver | 读取状态，搜索合法解法和提示 | 不修改活动对局 |
| LevelRepository | 读取并校验关卡配置 | 不加载远程代码 |
| SaveStore | 存档、迁移、备份、恢复与完成记录协调 | 不改变关卡规则 |
| AudioService | 音效、音乐和中断处理 | 不影响规则执行 |

规则引擎返回新状态、被消除的 tileID、受影响的 cellID、目标增量和动画事件。渲染层消费同一份结果，使预览与正式结算一致。

[Apple Core Animation 变换文档](https://developer.apple.com/documentation/quartzcore/transforms)提供图层透视和三维变换能力；首版使用单折面表现，不引入通用三维引擎。

## 文件组织

新增代码使用 CFV 前缀。

```text
Crealfanvar/
  App/
    CFVAppCoordinator.swift
  Features/
    Home/CFVHomeViewController.swift
    Levels/CFVLevelListViewController.swift
    Game/CFVGameViewController.swift
    Game/CFVBoardView.swift
    Game/CFVFoldAnimator.swift
    Game/CFVGameHUDView.swift
    Collection/CFVCollectionViewController.swift
    Collection/CFVCreatureDetailViewController.swift
    Settings/CFVSettingsViewController.swift
  GameCore/
    CFVBoardState.swift
    CFVGameAction.swift
    CFVGameEngine.swift
    CFVFoldProjection.swift
    CFVMatchResolver.swift
    CFVLevelDefinition.swift
    CFVHintSolver.swift
  Services/
    CFVLevelRepository.swift
    CFVSaveStore.swift
    CFVAudioService.swift
  Resources/
    Levels/
    Creatures/
    Localization/
    PrivacyInfo.xcprivacy

CrealfanvarTests/
  CFVGameEngineTests.swift
  CFVFoldProjectionTests.swift
  CFVSaveStoreTests.swift
  CFVLevelValidationTests.swift
```

测试目标及隐私清单在实现阶段按实际工程建立；本目录是规划，并非已经生成的应用代码。

## 数据模型

| 对象 | 必须包含的字段 |
| --- | --- |
| ReleaseCatalog | 有序 levelIDs、learningStages、creatures、totalLevels、totalCreatures、稳定美术阶段 |
| LevelDefinition | levelID、contentVersion、rulesVersion、学习阶段 ID、尺寸、初始格子、步数、折痕、教学标记、参考解法 |
| Cell | cellID、原始 row 和 column、可选 Tile |
| Tile | tileID、kind、isTarget |
| FoldDefinition | creaseID、axis、boundary、movingSide |
| BoardState | cellID 到 Tile 的映射、remainingMoves、状态版本、关卡版本 |
| ProjectionCell | 显示坐标、有序纸格栈、topCellID、可选可见 tileID |
| GameAction | swap 两个 cellID，或 fold 一个 creaseID |
| TurnResult | 新状态、消除 tileID 集合、目标增量、表现事件 |
| SessionSave | schemaVersion、关卡和规则版本、当前状态、动作历史、撤销快照、结果状态 |
| ProgressSave | schemaVersion、已完成关卡集合、最佳步数、已看教学、完成事件记录 |

目标总数来自初始目标棋子，剩余数来自当前还存在的目标棋子；已完成数为两者之差。不分别递增多个来源不明的计数器。

目标属于 Tile，随交换移动。cellID 用于命中和纸面投影，tileID 用于消除去重。空白纸格使用 tile = nil，纸格本身不删除。

## 关卡与收藏映射

[CFV-Release-Catalog.json](examples/CFV-Release-Catalog.json)是首版内容目录基线，不包含实际棋盘布局。实现阶段由 LevelRepository 加载对应目录，验证 12 份关卡数据齐全；界面总数、下一关和收藏条件由目录派生，不能分散硬编码。

| 生物 ID | 生物 | 对应关卡 | 解锁关卡 |
| --- | --- | --- | --- |
| paper-butterfly | 纸蝶 | 01、02 | 02 |
| folded-bird | 折翼鸟 | 03、04 | 04 |
| paper-fish | 纸鱼 | 05、06 | 06 |
| paper-rabbit | 纸兔 | 07、08 | 08 |
| paper-fox | 纸狐 | 09、10 | 10 |
| paper-deer | 纸鹿 | 11、12 | 12 |

生物制作进度取 completedLevelIDs 与该生物 requiredLevelIDs 的交集大小，得到 0、1 或 2；只有两关均完成才解锁。顺序解锁保证正常流程在偶数关触发奖励。重复通关不增加进度，跳过前置关的异常存档不得凭最大关卡号直接解锁。

界面总进度是目录内已完成关卡的数量除以 12，图鉴进度是已满足条件的生物数量除以 6。对每种生物使用未开始、半展开、完成三个稳定素材，6 种共 18 个。动画中间帧不作为额外存档阶段。

下一关通过有序目录查找，第 12 关之后返回 nil，展示完整图鉴与重玩入口。当前制作生物由下一个未完成关卡的所属生物确定；重玩已完成关卡时，局内插画取该关所属生物，不能回退长期收藏进度。

目录测试需覆盖 0/12 对应 0/6、2/12 对应 1/6、4/12 对应 2/6、6/12 对应 3/6、12/12 对应 6/6，所有奇数关的半展开状态，以及重复完成、缺失前置关、第 12 关无后继等边界。

## 规则执行

引擎为确定性转换：

```text
apply(level, state, action) -> accepted(newState, events) | rejected(reason)
preview(level, state, fold) -> projection + matches + targetDelta
```

同一输入得到同一结果。preview 和 apply 使用同一个投影和匹配函数，区别仅在于是否提交。

普通交换先产生候选状态，匹配后合法才提交。折叠先产生投影，对可见顶层匹配，再按 tileID 清除原始盘面中的实际棋子。没有掉落、补充或展开后二次连锁。

结算顺序：

1. 校验当前状态可操作、步数大于零、动作在关卡范围内。
2. 计算候选状态和匹配集合；无匹配则拒绝。
3. 保存撤销快照，清除唯一 tileID，步数减一。
4. 若剩余目标为零，标记通关。
5. 否则若步数为零，标记步数耗尽。
6. 否则枚举合法动作；为空时标记无合法动作，否则继续。
7. 提交存档，再由界面播放对应表现；存档失败进入显式恢复流程。

全部有效动作至少消除三枚棋子，因此搜索深度还受剩余棋子数量约束。折叠预览、取消、提示和无效交换不进入撤销历史。

## 折叠坐标和遮挡

逻辑坐标从零开始，r 表示行，c 表示列。竖直折痕位于第 k 列边界，即左侧有 k 列。

右侧向左折时，对 c ≥ k 的活动格子：

```text
projectedRow = r
projectedColumn = 2 * k - 1 - c
```

左侧向右折使用同一反射公式，但活动范围为 c < k。水平折叠相同：

```text
projectedRow = 2 * k - 1 - r
projectedColumn = c
```

配置校验必须确认每个活动格子的投影都在固定纸面范围内。固定区域保留原位置；活动区域只出现在映射位置，不得在原位置重复出现。

投影栈按固定纸面在下、活动纸面在上排列。topCellID 决定可见棋子；即使上层 tile 为 nil，也不能读取下层棋子补位。

对投影中每个显示位置的顶层图案进行横向和纵向扫描。空白、无纸面位置和不同图案打断连续段。长度至少三的段产生 tileID 集合，交叉段取并集，一次消除。

### 单步样例

[CFV-Fold-Example.json](examples/CFV-Fold-Example.json) 是规则验证样例，不计入正式 12 关。

折痕 k=4，右侧两列向左折：原 c=5 映射至 c=2，原 c=4 映射至 c=3。第 3 行从“叶、叶、圆、三角、叶、叶”投影为“叶、叶、叶、叶”。清除原 c=0、1、4、5 的四枚叶片，其中两枚带目标标记；被遮住的 c=2、3 保留，展开后重新显示。

样例通过这一折完成全部目标。参考解法用于核对公式、来源 ID、去重、遮挡和胜负优先级。

## 动画与交互状态机

状态包括 idle、selected、foldPreview、committing、animating、paused、won、failed。

- idle 和 selected 允许交换或预览折痕。
- foldPreview 只允许调整预览、确认或取消。
- committing 和 animating 锁定棋盘输入，防止重复扣步。
- 持久化成功后才展示已提交操作；失败则保留旧稳定状态，允许重试或返回。
- 后台中断未提交预览时丢弃预览；已提交动画中断时直接重建新稳定状态。
- 回前台进入暂停，不从中间旋转角度恢复游戏逻辑。
- won 与 failed 使用引擎状态，不能由动画完成回调独立计算。

活动纸片使用共同父图层按折痕设置锚点，CATransform3D 负责旋转与透视。正背面各一组图层，超过半转时切换可见面，并处理反向文字或图案的问题。纸面背面表达同一棋子，不改变逻辑类型。

纸片阴影提供预计算路径，避免每帧大面积动态模糊。动画只是同一数据的视觉表现；确认前的命中通过稳定棋盘坐标和折痕入口进行，折叠中的棋子不接受交换命中。

## 提示和关卡验证

提示求解与 UI 分离，运行于可取消的后台任务。先查找与当前棋盘状态及剩余步数匹配的缓存或已知参考路径；未命中则枚举全部合法交换和折叠。

搜索以棋盘图案、目标标记、关卡和规则版本、剩余步数作为状态键。可使用深度受限搜索和去重，且同一结构以更少剩余步数到达时不优于更多步数。原始 tileID 不决定图案规则，但映射回具体提示时仍需保留实际 cellID。

初始性能预算建议为最多 60,000 个搜索节点或 500 ms，先到者停止，并根据最低支持设备实测调整。使用请求 ID 与状态版本丢弃过期结果。返回枚举必须区分：

- foundPath：证明找到可在预算步数内完成的路径。
- provenNoSolution：穷尽相关搜索空间后确认无解。
- budgetExceeded：预算用尽，结果未知。
- cancelled：棋盘改变、页面退出或应用进入后台。

不能把搜索超时当成死局，也不能把随意合法一步称为保证通关的提示。

每个首发关卡通过以下构建期校验：尺寸和 ID 合法、三种类型有效、折痕映射合法、无初始自然匹配、目标非零、参考解法动作合法、在步数内清除全部目标、下一关解锁与图鉴映射完整。最少步数只是可选优化，不阻塞已证明可解的内容交付。

## 存档与恢复

使用 Codable 保存 JSON 到 Application Support，设置保存在 UserDefaults。当前对局与长期完成记录分文件保存，防止当前局损坏直接覆盖长期记录。每个文件保留一个已验证备份，采用原子替换。

当前对局最多保留本关全部有效动作的快照，36 格固定规模足够小。只有稳定状态写入，不持久化图层或动画时间。

通关跨文件一致性采用可重复执行流程：

1. 保存 outcome = won 的 SessionSave，附带唯一 completionID。
2. 将 levelID 合并到 ProgressSave，取更优步数，记录 completionID。
3. 保存奖励已展示或待展示状态。
4. 重启遇到 won 会话时重新协调；集合合并和 completionID 保证不会重复奖励。

进度属于已完成关卡集合，图鉴解锁由集合与首版目录共同推导。撤销不撤回长期完成记录。重玩通关只更新更优成绩。

当前范围修订发生在应用实现前，没有已发布玩家存档需要从旧范围迁移。若开发设备存在与当前目录不符的测试存档，识别版本并提示重置测试对局，不把旧编号直接计入总进度或收藏。正式发行后的迁移继续遵循下面的版本规则。

存档带 schemaVersion、contentVersion 和 rulesVersion。兼容升级执行已测试迁移；无法迁移当前棋盘时重开对应关卡并保留长期完成记录。未来关卡修订不得悄悄让旧存档按新规则继续。

当前对局文件损坏先读备份，再重建本关；进度文件损坏先读其独立备份。均失败时向用户说明受影响范围并保留故障文件。磁盘写入失败禁止显示虚假的“已保存”。

## 音频和资源

用 AVAudioPlayer 播放本地短音效和循环音乐，按实际播放并发数量建立轻量复用。配置尊重静音及其他音频的播放策略，响应系统中断与前后台切换。触感使用 UIKit Feedback Generator，支持关闭。

棋子使用独立资源和代码绘制外框；纸面材质裁剪缓存。大图按显示尺寸解码，不在棋盘动画中反复加载。每次只保留当前生物的阶段图和当前页面需要的缩略图。

本地化采用兼容 iOS 15 的系统资源方案，界面不拼接依赖中文语序的字符串。关卡配置引用本地化键，图片不烘焙用户界面文字。

## 隐私与外部入口

首版没有账号、广告 SDK、分析 SDK、网络关卡或设备指纹。核心功能离线。App 内数据是否上传和商店隐私申报必须按最终实现复核，不能仅依据“无账号”推断。

App 使用 UserDefaults 等 API 时，按 Apple 当前 required reason API 要求核对 PrivacyInfo.xcprivacy 和实际适用理由；不要填入未经核对的理由码。[Apple 隐私清单文档](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

隐私和支持页面由系统浏览器打开；配置发布前有效的真实地址。发布版不携带调试导出按钮或开发用文件路径。

## 性能与测试目标

性能数值是验收目标，需实测记录：以 iPhone SE 第二代级别设备为参考，常规棋盘交互目标 60 fps；折叠期间无持续超过 100 ms 的主线程停顿；冷启动到首页目标 2 秒以内；峰值内存初始预算 150 MB，安装体积初始预算 100 MB。

测试包含四层：

| 层级 | 核心验证 |
| --- | --- |
| 单元测试 | 交换、交叉匹配去重、四向折叠公式、空白遮挡、目标随棋子移动、最后一步通关 |
| 状态与持久化 | 取消不扣步、重复点击不重复提交、撤销恢复、保存失败、版本迁移、通关中断协调 |
| 内容测试 | 12 关参考解法全部重放，折痕和图鉴关系合法，教学引用有效 |
| UI 与真机 | 小屏、大字体、VoiceOver、减少动画、音频中断、离线、后台与重启、长时间操作 |

规则数据和引擎测试先完成，再制作全部关卡。性能验证使用 Instruments 和真机记录，不以模拟器流畅代替结论。
