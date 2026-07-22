import XCTest
@testable import MacWorkTimerCore

final class GWWebMenuClickScriptTests: XCTestCase {
    func testOffscreenWebViewClickDoesNotRequirePositiveElementBounds() {
        let script = GWWebMenuClickScript.make(label: "인사/근태")

        XCTAssertFalse(script.contains("getBoundingClientRect"))
        XCTAssertFalse(script.contains("rect.width"))
        XCTAssertTrue(script.contains("text === wanted"))
        XCTAssertTrue(script.contains("clickable.click()"))
    }

    func testEscapesMenuLabelForJavaScriptLiteral() {
        let script = GWWebMenuClickScript.make(label: "개인'근태\\현황")

        XCTAssertTrue(script.contains("개인\\'근태\\\\현황"))
    }

    func testFindsMenuLabelsRenderedByNonSemanticTags() {
        let script = GWWebMenuClickScript.make(label: "인사/근태")

        XCTAssertTrue(script.contains("querySelectorAll('*')"))
        XCTAssertTrue(script.contains("[onclick]"))
    }

    func testPersonnelMenuUsesBizboxTopMenuFunction() {
        let script = GWWebMenuClickScript.make(label: "인사/근태")

        XCTAssertTrue(script.contains("onclickTopCustomMenu"))
        XCTAssertTrue(script.contains("700000000"))
    }
}
