import XCTest

/// The optional tip jar, against the local StoreKit configuration (Tendr.storekit) attached to
/// the scheme. With `TEST_RUNNER_SCREENSHOT_DIR` set, key states are also written as PNGs.
final class TipJarTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testSupportRowShowsThreeTipsAtTheirPrices() {
        let app = launch()
        openTipJar(app, capture: true)
        for (id, name, price) in [("tip-small", "Coffee", "$0.99"), ("tip-medium", "Croissant", "$2.99"), ("tip-large", "Gift", "$4.99")] {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertTrue(button.label.contains(price), "\(id) should cost \(price), was \(button.label)")
            XCTAssertTrue(app.staticTexts[name].exists)
        }
        XCTAssertTrue(app.staticTexts["Tips are optional and unlock nothing. Every feature is free for everyone."].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["supportTendr"].waitForExistence(timeout: 5))
    }

    @MainActor func testTipPurchaseCelebratesThenCloses() {
        let app = launch()
        openTipJar(app)
        app.buttons["tip-small"].tap()
        confirmPurchase(in: app)
        let thanks = app.staticTexts["tipThanks"]
        XCTAssertTrue(thanks.waitForExistence(timeout: 20), "A completed tip shows the thank-you")
        // Mid-burst: the cannons fire as the cover appears.
        snap("tip-thanks", after: 0.7)
        XCTAssertTrue(app.staticTexts["Thank you"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["supportTendr"].waitForExistence(timeout: 5))
        XCTAssertFalse(thanks.exists)
    }

    @MainActor func testCancelledTipSaysNothing() {
        let app = launch()
        openTipJar(app)
        app.buttons["tip-medium"].tap()
        confirmPurchase(in: app, cancel: true)
        XCTAssertTrue(app.buttons["tip-medium"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tip-medium"].isEnabled)
        XCTAssertFalse(app.staticTexts["tipThanks"].exists)
        XCTAssertFalse(app.staticTexts["tipNotice"].exists, "Cancelling is not an error")
    }

    @MainActor func testThankYouCloses() {
        let app = launch(extra: ["--tip-thanks"])
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["tipThanks"].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        XCTAssertFalse(app.staticTexts["tipThanks"].waitForExistence(timeout: 2))
    }

    // MARK: - Helpers

    @MainActor private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitest", "-accentColor", "Graphite"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["logDose"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func openTipJar(_ app: XCUIApplication, capture: Bool = false) {
        app.tabBars.buttons["Settings"].tap()
        let row = app.buttons["supportTendr"]
        for _ in 0..<3 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 15), "The row appears once the StoreKit products load")
        if capture { snap("settings-support-row", after: 0.5) }
        row.tap()
        XCTAssertTrue(app.buttons["tip-small"].waitForExistence(timeout: 5))
        if capture { snap("tip-sheet", after: 1) }
    }

    /// StoreKit testing shows the system purchase sheet out of process.
    @MainActor private func confirmPurchase(in app: XCUIApplication, cancel: Bool = false) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let labels = cancel ? ["Cancel", "Close"] : ["Purchase", "Buy", "Confirm", "Pay", "Subscribe", "OK"]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            for source in [springboard, app] {
                for label in labels {
                    let button = source.buttons[label]
                    if button.exists && button.isHittable {
                        if !cancel { snap("purchase-sheet", after: 0.3) }
                        button.tap()
                        return
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        let tree = XCTAttachment(string: springboard.debugDescription + "\n\n" + app.debugDescription)
        tree.name = "hierarchies"
        tree.lifetime = .keepAlways
        add(tree)
        XCTFail("No StoreKit purchase sheet appeared")
    }

    @MainActor private func snap(_ name: String, after delay: TimeInterval) {
        Thread.sleep(forTimeInterval: delay)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !directory.isEmpty else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: url.appendingPathComponent("\(name).png"))
    }
}
