import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh ApprenticeHours.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["on the job"].firstMatch.waitForExistence(timeout: 15))
        sleep(1)   // let the ring finish drawing before the shutter
        snap("01-progress", app)

        tab("Hours", app)
        XCTAssertTrue(app.navigationBars["Hours"].waitForExistence(timeout: 5))
        snap("02-hours", app)

        app.navigationBars["Hours"].buttons["Log hours"].tap()
        XCTAssertTrue(app.navigationBars["Log Hours"].waitForExistence(timeout: 5))
        snap("03-log", app)
        app.buttons["Cancel"].tap()

        tab("Report", app)
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 5))
        snap("04-report", app)

        tab("Classes", app)
        XCTAssertTrue(app.navigationBars["Classes"].waitForExistence(timeout: 5))
        snap("05-classes", app)

        tab("Progress", app)
        XCTAssertTrue(app.buttons["How do I use this app"].waitForExistence(timeout: 5))
        app.buttons["How do I use this app"].tap()
        XCTAssertTrue(app.staticTexts["Set up your programme"].waitForExistence(timeout: 5))
        snap("06-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func tab(_ name: String, _ app: XCUIApplication) {
        let inTabBar = app.tabBars.buttons[name]
        if inTabBar.waitForExistence(timeout: 2) { inTabBar.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
