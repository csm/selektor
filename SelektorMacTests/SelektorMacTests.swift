//
//  SelektorMacTests.swift
//  SelektorMacTests
//
//  Created by Casey Marshall on 1/2/23.
//

import XCTest
@testable import SelektorMac

final class SelektorMacTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testWordWrap() throws {
        let result1 = wordWrap("The quick brown fox jumped over the lazy dog.", limit: 100, font: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        print("result: \(result1)")
    }
    
    func testPad() throws {
        let a1 = pad(array: [], to: 5, with: "foo")
        XCTAssertEqual(a1, ["foo", "foo", "foo", "foo", "foo"])
        let a2 = pad(array: ["foo", "bar", "baz"], to: 2, with: "quux")
        XCTAssertEqual(a2, ["foo", "bar", "baz"])
    }
}
