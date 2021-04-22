//
//  RingBufferrTests.swift
//  Created by Greg Fajen on 4/22/21.
//

import Foundation
import XCTest
@testable import Futures

class RingBufferTests: XCTestCase {

    func testBasic() {
        let buffer: RingBuffer = [1,2,3]

        XCTAssert(Array(buffer) == [1,2,3])
        XCTAssert(buffer.count == 3)
        XCTAssert(buffer.underestimatedCount == 3)
    }

    func testLoopAddRemove() {
        var buffer = RingBuffer<Int>()
        XCTAssert(buffer.count == 0)
        XCTAssert(buffer.isEmpty)

        for i in 1...100 {
            buffer.append(i)
            XCTAssert(buffer.count == 1)

            let j = buffer.removeFirst()
            XCTAssert(i == j)
            XCTAssert(buffer.count == 0)
            XCTAssert(buffer.isEmpty)
        }
    }

    func testAddAndRemoveALot() {
        var buffer = RingBuffer<Int>()
        XCTAssert(buffer.count == 0)
        XCTAssert(buffer.isEmpty)

        for i in 1...100 {
            buffer.append(i)
            XCTAssert(buffer.count == i)
        }

        for i in 1...100 {
            let j = buffer.removeFirst()
            XCTAssert(i == j)
            XCTAssert(buffer.count == 100 - i)
        }

        XCTAssert(buffer.isEmpty)
    }

    func testAddAndRemoveLopsided() {
        let adds = [5, 16, 3, 9]
        let removes = [3, 4, 15, 4]

        var buffer = RingBuffer<Int>(initialCapacity: 2)
        var count = 0

        for (add, remove) in zip(adds, removes) {
            for i in 1...add {
                buffer.append(i)
            }

            count += add
            XCTAssert(buffer.count == count)
            XCTAssert(Array(buffer.suffix(add)) == Array(1...add))

            buffer.removeFirst(remove)
            count -= remove
            XCTAssert(buffer.count == count)
        }
    }

    func testSuffix() {
        let buffer = RingBuffer([1,2,3])
        let suffix = buffer.suffix(2)

        XCTAssert(suffix.count == 2)
        XCTAssert(Array(suffix) == [2,3])
    }

    func testFullSuffix() {
        let buffer = RingBuffer([1,2,3])
        let suffix = buffer.suffix(3)

        XCTAssert(buffer.count == 3)
        XCTAssert(Array(suffix) == [1,2,3])
    }

    func testSubscriptGet() {
        let buffer = RingBuffer([1,2,3])
        XCTAssert(buffer[1] == 2)
    }

    func testSubscriptSet() {
        var buffer = RingBuffer([1,2,3])
        buffer[1] = 4
        XCTAssert(Array(buffer) == [1,4,3])
    }

    func testFirst() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        XCTAssert(buffer.first == 1)
    }

    func testLast() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        XCTAssert(buffer.last == 3)
    }

    func testIsEmptyBasic() {
        let buffer = RingBuffer<Int>(initialCapacity: 8)
        XCTAssert(buffer.isEmpty)
    }

    func testIsEmptyAfterDrop() {
        var buffer = RingBuffer([1,2,3])
        buffer = buffer.dropFirst(3)
        XCTAssert(buffer.isEmpty)
    }

    func testPowersOf2() {
        let result = (0...5).map(\.nextPowerOf2)
        let expected = [1,1,2,4,4,8]
        XCTAssert(result == expected)
    }

    func testEquality() {
        let expected = RingBuffer([1,2,3])

        var result = RingBuffer([0,0,1,2,3])
        result.removeFirst(2)

        XCTAssert(expected == result)
    }

    func testHashing() {
        var expected = Hasher()
        expected.combine(1)
        expected.combine(2)
        expected.combine(3)

        let buffer = RingBuffer([1,2,3])

        XCTAssert(buffer.hashValue == expected.finalize())
    }

    // MARK: - Popping

    func testPopFirst() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        let first = buffer.popFirst()

        XCTAssert(first == 1)
        XCTAssert(buffer.count == 2)
        XCTAssert(Array(buffer) == [2,3])
    }

    func testPopLast() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        let last = buffer.popLast()

        XCTAssert(last == 3)
        XCTAssert(buffer.count == 2)
        XCTAssert(Array(buffer) == [1,2])
    }

    func testPopFirstEmpty() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        XCTAssert(buffer.popFirst() == nil)
    }

    func testPopLastEmpty() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        XCTAssert(buffer.popLast() == nil)
    }

    // MARK: - Capacity

    func testDoubleCapacityBasic() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        XCTAssert(buffer.capacity == 8)

        buffer.doubleCapacity()
        XCTAssert(buffer.capacity == 16)

        XCTAssert(Array(buffer) == [1,2,3])
    }

    func testRedundantReserveCapacity() {
        var buffer = RingBuffer<Int>(initialCapacity: 8)
        XCTAssert(buffer.capacity == 8)

        buffer.reserveCapacity(8)
        XCTAssert(buffer.capacity == 8)
    }

    func testAppendAppropriatelyReservesCapacity() {
        var buffer = RingBuffer<Int>(initialCapacity: 2)
        XCTAssert(buffer.count == 0)
        XCTAssert(buffer.capacity == 2)

        buffer.append(1)
        XCTAssert(buffer.count == 1)
        XCTAssert(buffer.capacity == 2)

        buffer.append(1)
        XCTAssert(buffer.count == 2)
        XCTAssert(buffer.capacity == 4)

        buffer.append(1)
        XCTAssert(buffer.count == 3)
        XCTAssert(buffer.capacity == 4)

        buffer.append(1)
        XCTAssert(buffer.count == 4)
        XCTAssert(buffer.capacity == 8)
    }

    func testMiddleSubrangeInLoop() {
        var buffer = RingBuffer([0,1,2,3,4])

        for i in 5...100 {
            let expected = Array((i-3) ... (i-1))

            buffer.append(i)
            buffer.removeFirst()

            let lower = buffer.index(buffer.startIndex, offsetBy: 1)
            let upper = buffer.index(buffer.endIndex, offsetBy: -1)
            let range = lower ..< upper
            let slice = buffer[range]

            XCTAssert(buffer.distance(from: lower, to: upper) == 3)
            XCTAssert(buffer.distance(from: upper, to: lower) == -3)

            XCTAssert(buffer.count == 5)
            XCTAssert(slice.count == 3)
            XCTAssert(Array(slice) == expected)
        }
    }


    func testSuffixInLoop() {
        var buffer = RingBuffer([0,1,2,3,4])

        for i in 5...100 {
            let expected = Array((i-2) ... (i))

            buffer.append(i)
            buffer.removeFirst()

            let slice = buffer.suffix(3)

            XCTAssert(buffer.count == 5)
            XCTAssert(slice.count == 3)
            XCTAssert(Array(slice) == expected)
        }
    }

    func testIndexComparisonBasic() {
        let buffer = RingBuffer([1,2,3])

        XCTAssertTrue(buffer.startIndex < buffer.endIndex)
        XCTAssertFalse(buffer.endIndex < buffer.startIndex)
    }

    func testIndexComparisonWrapped() {
        var buffer = RingBuffer([1,2,3])
        XCTAssert(buffer.capacity == 4)

        buffer.removeFirst(2)
        buffer.append(4)
        buffer.append(5)

        XCTAssert(buffer.startIndex.backingIndex > buffer.endIndex.backingIndex)
        XCTAssert(buffer.count == 3)

        XCTAssertTrue(buffer.startIndex < buffer.endIndex)
        XCTAssertFalse(buffer.endIndex < buffer.startIndex)
    }

}
