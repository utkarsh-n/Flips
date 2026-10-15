import XCTest

@MainActor
final class FlipsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        await MainActor.run {
            continueAfterFailure = false
            XCUIDevice.shared.orientation = .portrait
            app = XCUIApplication()
            app.launchArguments = ["--ui-testing"]
            app.launch()
        }
    }

    func testSwitchboardAddsAndRemovesTheCorrectWeights() {
        assertReadouts(decimal: "42", binary: "00101010", hex: "2A")

        tap("bit0")
        scrollToTop()
        assertReadouts(decimal: "43", binary: "00101011", hex: "2B")

        tap("bit5")
        scrollToTop()
        assertReadouts(decimal: "11", binary: "00001011", hex: "0B")
    }

    func testHexConversionAndByteOverflow() {
        selectTab("Bases")
        replaceBaseInput(with: "FF")
        tap("convertNumber")
        scrollToTop()
        assertReadouts(decimal: "255", binary: "11111111", hex: "FF")

        tap("baseIncrement")
        scrollToTop()
        assertReadouts(decimal: "0", binary: "00000000", hex: "00")
        let explanation = element("baseCountingExplanation")
        reveal(explanation)
        assertText(in: explanation, contains: "ninth bit")
        assertText(in: explanation, contains: "wraps back to 0")
    }

    func testInvalidBinaryDigitPreservesTheNumber() {
        selectTab("Bases")
        let picker = app.segmentedControls["basePicker"]
        reveal(picker)
        picker.buttons.element(boundBy: 0).tap()

        replaceBaseInput(with: "2")
        tap("convertNumber")
        let error = element("baseInputError")
        reveal(error)
        assertText(in: error, contains: "not a digit in base 2")

        scrollToTop()
        assertReadouts(decimal: "42", binary: "00101010", hex: "2A")
    }

    func testMissionRequiresACorrectAnswerAndResetsTheNextAnswer() {
        selectTab("Discover")
        assertProgress("0 / 10")

        tap("checkAnswer")
        let wrongFeedback = element("missionFeedback")
        reveal(wrongFeedback)
        assertText(in: wrongFeedback, contains: "Keep experimenting")
        scrollToTop()
        assertProgress("0 / 10")

        tap("bit0")
        tap("checkAnswer")
        let correctFeedback = element("missionFeedback")
        reveal(correctFeedback)
        assertText(in: correctFeedback, contains: "Binary 00000001 is decimal 1")
        scrollToTop()
        assertProgress("1 / 10")

        tap("nextMission")
        scrollToTop()
        XCTAssertTrue(app.staticTexts["Two places"].waitForExistence(timeout: 3))
        assertProgress("1 / 10")
        let decimal = app.staticTexts["decimalReadout"]
        reveal(decimal)
        assertLabel(decimal, equals: "0")
        assertLabel(app.staticTexts["binaryReadout"], equals: "00000000")
        XCTAssertFalse(element("missionFeedback").exists)
    }

    func testXORResultCanBecomeTheSwitchboardNumber() {
        tap("openLogic")
        let operation = app.segmentedControls["logicOperation"]
        reveal(operation, direction: .down)
        XCTAssertTrue(operation.buttons["XOR"].isSelected)

        let useResult = app.buttons["useLogicResult"]
        reveal(useResult)
        XCTAssertTrue(useResult.label.contains("Use 37 on the switchboard"))
        useResult.tap()

        scrollToTop()
        assertReadouts(decimal: "37", binary: "00100101", hex: "25")
    }

    func testFullBytePresetCarriesBeyondEightBits() {
        tap("preset255")
        tap("increment", direction: .down)
        scrollToTop()
        assertReadouts(decimal: "0", binary: "00000000", hex: "00")

        let explanation = element("changeExplanation")
        reveal(explanation)
        assertText(in: explanation, contains: "255 wraps to 0")
        assertText(in: explanation, contains: "ninth bit")
    }

    func testSlowCarryVisitsFivePlacesAndCommitsSixteen() {
        startSlowArithmetic(from: 15, operation: "increment")
        assertArithmeticCompletion(decimal: "16", binary: "00010000", hex: "10", steps: 5)

        selectTab("Bases")
        scrollToTop()
        assertReadouts(decimal: "16", binary: "00010000", hex: "10")
    }

    func testSlowBorrowVisitsFivePlacesAndCommitsFifteen() {
        startSlowArithmetic(from: 16, operation: "decrement")
        assertArithmeticCompletion(decimal: "15", binary: "00001111", hex: "0F", steps: 5)

        selectTab("Bases")
        scrollToTop()
        assertReadouts(decimal: "15", binary: "00001111", hex: "0F")
    }

    func testSlowFullByteCarryIncludesTheNinthPlaceBeforeWrapping() {
        startSlowArithmetic(from: 255, operation: "increment")
        assertArithmeticCompletion(decimal: "0", binary: "00000000", hex: "00", steps: 9)

        selectTab("Bases")
        scrollToTop()
        assertReadouts(decimal: "0", binary: "00000000", hex: "00")
    }

    func testPausedArithmeticAllowsOneManualStepAndCancelPreservesTheSource() {
        startSlowArithmetic(from: 255, operation: "increment")
        tap("arithmeticPauseToggle", direction: .down)
        assertLabel(app.buttons["arithmeticPauseToggle"], equals: "Resume")

        let progress = app.staticTexts["arithmeticProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        let completed = Int(progress.label.split(separator: "/").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        guard let completed else {
            XCTFail("Could not read arithmetic progress: \(progress.label)")
            return
        }
        XCTAssertLessThan(completed, 8, "Pause must leave an unfinished trace to cancel after a manual step")

        let unwantedAutomaticStep = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", progress.label), object: progress
        )
        unwantedAutomaticStep.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [unwantedAutomaticStep], timeout: 0.9), .completed,
                       "A paused trace advanced without a manual step")

        tap("arithmeticNextBit")
        waitForLabel(progress, equals: "\(completed + 1) / 9", timeout: 3)
        assertLabel(app.buttons["arithmeticPauseToggle"], equals: "Resume")

        tap("arithmeticCancel")
        XCTAssertFalse(element("arithmeticTracePanel").exists)
        scrollToTop()
        assertReadouts(decimal: "255", binary: "11111111", hex: "FF")
    }

    private enum ScrollDirection {
        case up
        case down
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func selectTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing \(title) tab", file: file, line: line)
        tab.tap()
    }

    private func tap(
        _ identifier: String,
        direction: ScrollDirection = .up,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons[identifier]
        guard reveal(button, direction: direction, file: file, line: line) else { return }
        button.tap()
    }

    @discardableResult
    private func reveal(
        _ target: XCUIElement,
        direction: ScrollDirection = .up,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        if isVisible(target) { return true }
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 3) else {
            XCTFail("No scroll view available to reveal \(target)", file: file, line: line)
            return false
        }
        for _ in 0..<8 {
            if isVisible(target) { return true }
            switch direction {
            case .up: scrollView.swipeUp()
            case .down: scrollView.swipeDown()
            }
        }
        let visible = isVisible(target)
        XCTAssertTrue(visible, "Could not reveal \(target) after eight swipes", file: file, line: line)
        return visible
    }

    private func isVisible(_ target: XCUIElement) -> Bool {
        guard target.exists else { return false }
        let frame = target.frame
        guard !frame.isEmpty,
              app.frame.insetBy(dx: 0, dy: 80).contains(CGPoint(x: frame.midX, y: frame.midY)) else { return false }
        return target.isHittable
    }

    private func scrollToTop() {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }
        for _ in 0..<8 {
            if element("screenHeader").isHittable { return }
            scrollView.swipeDown()
        }
    }

    private func replaceBaseInput(with text: String) {
        let field = app.textFields["baseInput"]
        guard reveal(field) else { return }
        field.tap()
        let oldText = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldText.count) + text)
    }

    private func startSlowArithmetic(from source: Int, operation: String) {
        let slowMotion = app.switches["slowMotionToggle"]
        guard reveal(slowMotion) else { return }
        if slowMotion.value as? String != "1" { slowMotion.tap() }
        XCTAssertEqual(slowMotion.value as? String, "1", "Slow motion was not enabled")

        tap("preset\(source)")
        tap(operation, direction: .down)
        XCTAssertTrue(element("arithmeticTracePanel").waitForExistence(timeout: 3))
    }

    private func assertArithmeticCompletion(
        decimal: String,
        binary: String,
        hex: String,
        steps: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitForLabel(app.staticTexts["arithmeticProgress"], equals: "\(steps) / \(steps)", timeout: 6,
                     file: file, line: line)
        assertLabel(app.staticTexts["arithmeticWorkingValue"], equals: decimal, file: file, line: line)
        assertLabel(app.staticTexts["arithmeticWorkingBinary"], equals: binary, file: file, line: line)
        assertLabel(app.staticTexts["arithmeticWorkingHex"], equals: hex, file: file, line: line)
    }

    private func waitForLabel(
        _ target: XCUIElement,
        equals expected: String,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", expected), object: target
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "Expected \(expected); found \(target.exists ? target.label : "missing element")",
                       file: file, line: line)
    }

    private func assertReadouts(
        decimal: String,
        binary: String,
        hex: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertLabel(app.staticTexts["decimalReadout"], equals: decimal, file: file, line: line)
        assertLabel(app.staticTexts["binaryReadout"], equals: binary, file: file, line: line)
        assertLabel(app.staticTexts["hexReadout"], equals: hex, file: file, line: line)
    }

    private func assertLabel(
        _ target: XCUIElement,
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing readout", file: file, line: line)
        XCTAssertEqual(target.label, expected, "Incorrect readout", file: file, line: line)
    }

    private func assertProgress(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let progress = element("missionProgress")
        reveal(progress, file: file, line: line)
        assertText(in: progress, contains: expected, file: file, line: line)
    }

    /// SwiftUI may expose a card as a combined label or keep its text in descendants.
    private func assertText(
        in container: XCUIElement,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(container.waitForExistence(timeout: 3), "Missing accessibility container", file: file, line: line)
        let labels = [container.label] + container.descendants(matching: .any).allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.contains(expected) },
                      "Expected text containing \(expected); found \(labels)", file: file, line: line)
    }
}
