//
//  SelektorTests.swift
//  SelektorTests
//
//  Created by Casey Marshall on 11/29/22.
//

import XCTest
@testable import Selektor
import SwiftMsgpack
import Erik
import WebKit

final class SelektorTests: XCTestCase {

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
    
    func testEncodeResult() throws {
        let results: [Result] = [
            .IntegerResult(integer: 42),
            .FloatResult(float: 3.14159),
            .PercentResult(value: 50),
            .StringResult(string: "test"),
            .ImageResult(imageData: "abc".data(using: .utf8)!)
        ]
        try results.forEach { result in
            let encoder = MsgPackEncoder()
            let encoded = try encoder.encode(result)
            let decoder = MsgPackDecoder()
            let decoded = try decoder.decode(Result.self, from: encoded)
            XCTAssertEqual(result, decoded)
        }
    }

    /*
    func testWebkitQuerySelector() async throws {
        let _ = WKWebViewConfiguration()
        let document = try await withCheckedThrowingContinuation {
            continuation in
            Erik.visit(url: URL(string: "https://www.duckduckgo.com")!) { result, error in
                if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: error!)
                }
            }
        }
        let selected = document.querySelectorAll(".badge-link__title")
        print("selected: \(selected)")
    }
     */
}
