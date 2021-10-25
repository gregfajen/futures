//
//  FutureTests.swift
//  Created by Greg Fajen on 4/22/21.
//

import Foundation
@testable import Futures
import XCTest

class FutureTests: XCTestCase {
    func testBasic() {
        let e = expectation(description: "")

        let promise = Promise<Void>(on: .background)
        let future = promise.future

        future.whenSuccess { e.fulfill() }

        promise.succeed(())

        waitForExpectations(timeout: 1)
    }

    func testBasicOnMain() {
        dispatchPrecondition(condition: .onQueue(.main))

        let e = expectation(description: "")

        let promise = Promise<Void>(on: .main)
        let future = promise.future

        future.whenSuccess { e.fulfill() }

        promise.succeed(())

        waitForExpectations(timeout: 1)
    }

    func testCascade() {
        let e = expectation(description: "")

        let promiseBack = Promise<Void>(on: .background)
        let promiseMain = Promise<Void>(on: .main)

        promiseBack.future.cascade(to: promiseMain)

        promiseMain.future.whenSuccess {
            dispatchPrecondition(condition: .onQueue(.main))
            e.fulfill()
        }

        promiseBack.succeed(())

        waitForExpectations(timeout: 1)
    }

    func testCascadeOnSameQueue() {
        let e = expectation(description: "")

        let promiseBack = Promise<Void>(on: .background)
        let promiseMain = Promise<Void>(on: .main)

        promiseBack.future.cascade(to: promiseMain)

        promiseMain.future.whenSuccess {
            dispatchPrecondition(condition: .onQueue(.main))
            e.fulfill()
        }

        FutureQueue.background.async {
            XCTAssert(promiseBack.future.queue.isOnQueue)
            promiseBack.succeed(())
        }

        waitForExpectations(timeout: 1)
    }

    func testMap() {
        let e = expectation(description: "")
        var result = 0

        let promise = Promise<Int>(on: .background)
        let future = promise.future

        future
            .map { $0 + 3 }
            .whenSuccess {
                result = $0
                e.fulfill()
            }

        promise.succeed(5)

        waitForExpectations(timeout: 1)
        XCTAssert(result == 8)
    }
}
