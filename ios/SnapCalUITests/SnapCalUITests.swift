import XCTest

/// SnapCal 新功能端到端测试 (模拟器运行, 连接线上后端)
/// 前置: 线上开启 dev-login; 米饭已在收藏 (bash 预置)
final class SnapCalUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 直接调后端 dev-login 拿 token (runner 进程有网络)
    private func fetchToken() -> String {
        var req = URLRequest(url: URL(string: "http://myblog.wiki:8081/api/auth/dev-login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["username": "yupan"])
        var token = ""
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { sem.signal() }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = json["data"] as? [String: Any],
                  let t = payload["token"] as? String else { return }
            token = t
        }.resume()
        sem.wait()
        return token
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-snapcal-onboarded", "1",
                                "-snapcal-auth-token", fetchToken()]
        app.launch()
        return app
    }

    /// 启动并确保进入主界面; 偶发落到登录页时通过 UI 走开发登录兜底
    @discardableResult
    private func launchToMain() -> XCUIApplication {
        let app = launchApp()
        if app.staticTexts["今日概览"].waitForExistence(timeout: 15) {
            return app
        }
        // 登录页兜底: 开发模式登录
        let devEntry = app.staticTexts["开发模式登录 (调试)"]
        XCTAssertTrue(devEntry.waitForExistence(timeout: 5), "既不在主界面也不是登录页")
        devEntry.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("yupan")
        app.buttons["登录"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["今日概览"].waitForExistence(timeout: 15), "开发登录后应进入主界面")
        return app
    }

    /// 清空今天的餐次 (测试数据隔离)
    private func cleanupTodayMeals() {
        let token = fetchToken()
        var req = URLRequest(url: URL(string: "http://myblog.wiki:8081/api/meal/day")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { sem.signal() }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let meals = json["data"] as? [[String: Any]] else { return }
            let group = DispatchGroup()
            for meal in meals {
                guard let id = meal["id"] as? Int else { continue }
                var del = URLRequest(url: URL(string: "http://myblog.wiki:8081/api/meal/\(id)")!)
                del.httpMethod = "DELETE"
                del.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                group.enter()
                URLSession.shared.dataTask(with: del) { _, _, _ in group.leave() }.resume()
            }
            group.wait()
        }.resume()
        sem.wait()
    }

    /// 今日页: 水卡 + 餐次列表渲染
    func test01_TodayPageWaterCard() throws {
        let app = launchToMain()
        XCTAssertTrue(app.staticTexts["早餐"].exists)
        XCTAssertTrue(app.staticTexts["加餐"].exists)

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["今日饮水"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["＋200"].exists, "应有 +200 快捷饮水按钮")
        XCTAssertTrue(app.buttons["＋500"].exists, "应有 +500 快捷饮水按钮")
    }

    /// 手动记录全流程: + → 收藏快捷添加米饭 → 保存 → 今日页已记 1 项
    func test02_ManualMealEndToEnd() throws {
        cleanupTodayMeals()
        let app = launchToMain()

        // 打开手动记录 (右上角 +)
        app.buttons["add-meal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["手动记录"].waitForExistence(timeout: 6), "应打开手动记录页")

        // 收藏快捷添加: 米饭
        let riceChip = app.buttons.containing(.staticText, identifier: "米饭").firstMatch
        XCTAssertTrue(riceChip.waitForExistence(timeout: 8), "收藏区应出现「米饭」快捷项")
        riceChip.tap()

        // 明细出现且默认 100g
        XCTAssertTrue(app.staticTexts["合计 116 kcal"].waitForExistence(timeout: 4),
                      "米饭 100g 应为 116 kcal")

        // 保存 (identifier 定位; 若失效则点按钮中心坐标)
        let saveButton = app.buttons["save-meal"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4))
        if saveButton.isHittable {
            saveButton.tap()
        } else {
            let coord = saveButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coord.tap()
        }

        // 回到今日页, 某餐次显示已记 1 项
        XCTAssertTrue(app.staticTexts["已记 1 项"].waitForExistence(timeout: 10), "保存后今日页应显示已记 1 项")
    }

    /// 记录页 → 详情 → 编辑入口存在
    func test03_HistoryDetailAndEdit() throws {
        let app = launchToMain()

        // 切到记录 tab
        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.navigationBars["饮食记录"].waitForExistence(timeout: 6))

        // 点含「米饭」的餐卡进详情 (食物 chip 文本: "🍚 米饭 100g")
        let riceChip = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '米饭'")).firstMatch
        XCTAssertTrue(riceChip.waitForExistence(timeout: 8), "记录页应有米饭餐卡")
        riceChip.tap()

        XCTAssertTrue(app.navigationBars["餐次详情"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.navigationBars.buttons["编辑"].exists, "详情页应有编辑入口")
        app.navigationBars.buttons["关闭"].tap()
    }

    /// 我的页: 用餐提醒设置入口
    func test04_ReminderSettingsEntry() throws {
        let app = launchToMain()

        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["用餐提醒"].waitForExistence(timeout: 6))
        app.staticTexts["用餐提醒"].tap()
        XCTAssertTrue(app.staticTexts["每日用餐提醒"].waitForExistence(timeout: 6), "应打开提醒设置页")
        XCTAssertTrue(app.switches.firstMatch.exists, "应有提醒开关")
        app.navigationBars.buttons["完成"].tap()
    }
}
