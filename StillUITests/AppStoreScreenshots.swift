import XCTest

/// Captures the App Store screenshots from the synthetic `--screenshots` journal.
/// Run through `scripts/capture-screenshots.sh`, which overrides the status bar and passes
/// `TEST_RUNNER_SCREENSHOTS_DIR` so PNGs land on the host as well as in the result bundle.
final class AppStoreScreenshots: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor func testCaptureAppStoreScreenshots() throws {
        let light = launch(dark: false)
        XCTAssertTrue(light.buttons["logDose"].waitForExistence(timeout: 20))
        try capture("01-home")

        light.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(light.staticTexts["pageHeader-Progress"].waitForExistence(timeout: 5))
        try capture("02-progress")

        light.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(light.staticTexts["pageHeader-Journal"].waitForExistence(timeout: 5))
        try capture("03-journal")
        light.terminate()

        let dark = launch(dark: true)
        XCTAssertTrue(dark.buttons["logDose"].waitForExistence(timeout: 20))
        try capture("04-home-dark")

        dark.tabBars.buttons["Settings"].tap()
        let privacy = dark.buttons["Privacy & About"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        privacy.tap()
        XCTAssertTrue(dark.navigationBars["Privacy & About"].waitForExistence(timeout: 5))
        try capture("05-privacy-dark")
    }

    @MainActor private func launch(dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshots", "--uitest", "-accentColor", "Graphite"] + (dark ? ["--dark"] : [])
        app.launch()
        return app
    }

    @MainActor private func capture(_ name: String) throws {
        // Let charts and navigation transitions settle.
        Thread.sleep(forTimeInterval: 1.5)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOTS_DIR"], !directory.isEmpty else { return }
        try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
