import XCTest

@MainActor
final class CFVUITests: XCTestCase {
    let app = XCUIApplication()
    let solutions: [[(String, Int, Int, String)]] = [
        [("swap", 31, 32, "")],
        [("fold", 0, 0, "right-4")],
        [("fold", 0, 0, "left-2"), ("swap", 31, 32, "")],
        [("swap", 2, 8, ""), ("fold", 0, 0, "right-4")],
        [("swap", 17, 23, ""), ("fold", 0, 0, "right-4")],
        [("fold", 0, 0, "bottom-4"), ("swap", 13, 14, "")],
        [("fold", 0, 0, "right-4"), ("swap", 12, 13, "")],
        [("fold", 0, 0, "bottom-4"), ("fold", 0, 0, "left-2")],
        [("swap", 24, 25, ""), ("fold", 0, 0, "top-2"), ("fold", 0, 0, "right-4")],
        [("swap", 28, 29, ""), ("fold", 0, 0, "bottom-4"), ("swap", 20, 26, "")],
        [("fold", 0, 0, "bottom-4"), ("swap", 3, 4, ""), ("fold", 0, 0, "left-2")],
        [("swap", 1, 2, ""), ("fold", 0, 0, "top-2"), ("swap", 26, 32, ""), ("fold", 0, 0, "right-4")]
    ]
    override func setUpWithError() throws { continueAfterFailure = false }
    func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func tap(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 6), id)
        for _ in 0..<3 where !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.isHittable, id + " hittable")
        button.tap()
    }
    func dismissTutorial() {
        if app.alerts.buttons["试试看"].waitForExistence(timeout: 1) { app.alerts.buttons["试试看"].tap() }
    }
    func action(_ action: (String, Int, Int, String), inspect: Bool = false) {
        if action.0 == "swap" { tap("cell-\(action.1)"); tap("cell-\(action.2)") }
        else {
            tap("fold-" + action.3)
            XCTAssertTrue(app.buttons["confirm-fold"].waitForExistence(timeout: 4))
            if inspect {
                shot("fold-preview")
                let before = app.staticTexts["game-hud"].label
                tap("cancel-fold")
                XCTAssertEqual(app.staticTexts["game-hud"].label, before)
                tap("fold-" + action.3)
            }
            tap("confirm-fold")
        }
    }
    func testFullChineseJourneyAndRecovery() {
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        shot("01-home-zh")
        tap("home-start")
        for index in 0..<12 {
            dismissTutorial()
            XCTAssertTrue(app.staticTexts["game-hud"].waitForExistence(timeout: 5))
            if index == 0 { shot("02-gameplay-zh") }
            if index == 4 { shot("03-level05-zh") }
            for (step, move) in solutions[index].enumerated() {
                if index == 3 && step == 0 {
                    action(move)
                    tap("undo")
                    action(move)
                    app.terminate()
                    app.launch()
                    tap("home-start")
                    XCTAssertTrue(app.staticTexts["game-hud"].label.contains("剩余 1 步"))
                } else { action(move, inspect: index == 1 || index == 8) }
            }
            XCTAssertTrue(app.staticTexts[String(format: "第 %02d 关完成", index + 1)].waitForExistence(timeout: 5))
            if index == 5 { shot("04-fish-unlocked-zh") }
            if index < 11 { tap("下一关") }
        }
        tap("查看完整图鉴")
        XCTAssertTrue(app.staticTexts["已发现 6 / 6"].waitForExistence(timeout: 5))
        shot("05-collection-zh")
        tap("creature-0")
        tap("再次展开")
        shot("06-detail-zh")
    }
    func testEnglishSmallScreenAndSettings() {
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        shot("07-home-en-small")
        tap("settings")
        let reduced = app.switches["Reduce motion"]
        XCTAssertTrue(reduced.waitForExistence(timeout: 3))
        if reduced.value as? String == "0" { reduced.tap() }
        shot("08-settings-en-small")
        tap("settings-back")
        tap("home-start")
        for index in 0..<12 {
            if app.alerts.buttons["Let's try"].waitForExistence(timeout: 1) { app.alerts.buttons["Let's try"].tap() }
            XCTAssertTrue(app.staticTexts["game-hud"].waitForExistence(timeout: 5))
            let cell = app.buttons["cell-0"]
            XCTAssertGreaterThanOrEqual(cell.frame.width, 44)
            XCTAssertGreaterThanOrEqual(cell.frame.height, 44)
            if index == 0 { shot("09-game-en-small-large-text") }
            if index == 8 { shot("10-blank-paper-en-small") }
            for move in solutions[index] { action(move, inspect: index == 1) }
            XCTAssertTrue(app.staticTexts[String(format: "Level %02d complete", index + 1)].waitForExistence(timeout: 5))
            if index < 11 { tap("Next level") }
        }
        tap("View complete collection")
        XCTAssertTrue(app.staticTexts["Discovered 6 / 6"].waitForExistence(timeout: 5))
        shot("11-collection-en-small")
    }

    func testReleaseChineseScreensAndGestures() {
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        shot("Release-01-home-zh")
        tap("关卡册")
        shot("Release-02-level-book-zh")
        tap("level-4")
        if app.alerts["替换当前对局？"].waitForExistence(timeout: 1) { tap("继续") }
        dismissTutorial()
        tap("帮助")
        for page in ["02 · 折叠", "03 · 遮挡", "04 · 菱形目标"] {
            tap("下一页")
            XCTAssertTrue(app.staticTexts[page].waitForExistence(timeout: 3))
        }
        tap("完成")
        action(("fold", 0, 0, "top-2"))
        action(("fold", 0, 0, "right-4"))
        XCTAssertTrue(app.alerts["步数用完了"].waitForExistence(timeout: 4))
        shot("Release-failure-recovery-zh")
        tap("撤销上一步")
        tap("hint")
        XCTAssertTrue(app.alerts["试试撤销"].waitForExistence(timeout: 6))
        tap("知道了")
        tap("undo")
        tap("hint")
        XCTAssertTrue(app.alerts["提示"].waitForExistence(timeout: 6))
        tap("显示操作")
        action(solutions[3][0])
        app.activate()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.alerts["暂停"].waitForExistence(timeout: 5))
        tap("继续")
        action(solutions[3][1])
        tap("下一关")
        shot("Release-03-gameplay-zh")
        action(solutions[4][0])
        tap("fold-right-4")
        shot("Release-04-fold-preview-zh")
        tap("cancel-fold")
        XCTAssertTrue(app.buttons["fold-right-4"].waitForExistence(timeout: 4))
        // Direct crease hit testing and edge dragging both open a noncommitting preview.
        let lower = app.buttons["cell-34"].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: lower.minX, dy: lower.midY)).tap()
        XCTAssertTrue(app.buttons["confirm-fold"].waitForExistence(timeout: 4))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.alerts["暂停"].waitForExistence(timeout: 5))
        tap("继续")
        XCTAssertFalse(app.buttons["confirm-fold"].exists)
        let edge = app.buttons["cell-17"]
        let from = edge.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let to = edge.coordinate(withNormalizedOffset: CGVector(dx: -1, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(app.buttons["confirm-fold"].waitForExistence(timeout: 4))
        tap("confirm-fold")
        tap("下一关")
        for move in solutions[5] { action(move) }
        shot("Release-05-completion-zh")
        tap("返回关卡册")
        tap("图鉴")
        shot("Release-06-collection-zh")
        tap("creature-2")
        tap("再次展开")
        shot("Release-07-fish-detail-zh")
    }

    func testSmallLayoutRegression() {
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        tap("Level book")
        tap("level-7")
        shot("Final-small-game-large-text")
        XCTAssertGreaterThanOrEqual(app.buttons["cell-0"].frame.width, 44)
        tap("fold-right-4")
        shot("Final-small-preview-large-text")
        tap("cancel-fold")
        tap("hint")
        tap("Show move")
        tap("OK")
        for move in solutions[6] { action(move) }
        XCTAssertTrue(app.staticTexts["Level 07 complete"].waitForExistence(timeout: 5))
        tap("Back to level book")
        tap("Collection")
        shot("Final-small-collection-large-text")
    }

    func testMotionCancellationAndReducedMotion() {
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        tap("settings")
        let reduced = app.switches["减少动态效果"]
        XCTAssertTrue(reduced.waitForExistence(timeout: 3))
        let wasReduced = reduced.value as? String == "1"
        if wasReduced { reduced.tap() }
        tap("settings-back")
        tap("关卡册")
        tap("level-8")
        if app.alerts["替换当前对局？"].waitForExistence(timeout: 1) { tap("继续") }
        dismissTutorial()
        let initialHUD = app.staticTexts["game-hud"].label
        for crease in ["left-2", "bottom-4"] {
            tap("fold-" + crease)
            XCTAssertTrue(app.buttons["confirm-fold"].waitForExistence(timeout: 4))
            shot("Motion-preview-" + crease)
            tap("cancel-fold")
            XCTAssertTrue(app.buttons["fold-" + crease].waitForExistence(timeout: 4))
            XCTAssertEqual(app.staticTexts["game-hud"].label, initialHUD)
        }
        tap("fold-left-2")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.alerts["暂停"].waitForExistence(timeout: 5))
        tap("继续")
        XCTAssertFalse(app.buttons["confirm-fold"].exists)
        XCTAssertEqual(app.staticTexts["game-hud"].label, initialHUD)

        action(solutions[7][0])
        tap("pause")
        tap("继续")
        tap("undo")
        XCTAssertEqual(app.staticTexts["game-hud"].label, initialHUD)
        tap("pause")
        tap("设置")
        XCTAssertTrue(reduced.waitForExistence(timeout: 3))
        reduced.tap()
        shot("Motion-settings-page")
        tap("settings-back")
        tap("fold-left-2")
        tap("cancel-fold")
        XCTAssertTrue(app.buttons["fold-left-2"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["game-hud"].label, initialHUD)
        tap("pause")
        tap("设置")
        reduced.tap()
        tap("settings-back")
        tap("返回关卡册")
        tap("图鉴")
        tap("creature-0")
        tap("再次展开")
        tap("再次展开")
        Thread.sleep(forTimeInterval: 2)
        shot("Motion-creature-settled")
        XCTAssertTrue(app.staticTexts["制作完成 · 2 / 2"].exists)
        if wasReduced {
            tap("返回")
            tap("首页")
            tap("settings")
            reduced.tap()
            tap("settings-back")
        }
    }

}
