//
//  RingBuffer.swift
//  Created by Greg Fajen on 4/21/21.
//

import Foundation

public struct RingBuffer<Element>: ExpressibleByArrayLiteral {

    var backing: ContiguousArray<Element?>
    var head: Int = 0
    var tail: Int = 0

    public var isEmpty: Bool { head == tail }
    public var count: Int {
        if tail >= head {
            return tail &- head
        } else {
            return capacity &- (head &- tail)
        }
    }

    var capacity: Int { backing.count }
    var mask: Int { capacity &- 1 } // capacity will never be zero

    // MARK: - Initialization

    public init(initialCapacity: Int) {
        let capacity = initialCapacity.nextPowerOf2
        self.backing = ContiguousArray<Element?>(repeating: nil, count: capacity)
    }

    public init() {
        self = .init(initialCapacity: 16)
    }

    public init<S>(_ elements: S) where S: Sequence, Self.Element == S.Element {
        var buffer = Self(initialCapacity: elements.underestimatedCount)
        for element in elements {
            buffer.append(element)
        }

        self = buffer
    }

    public init(arrayLiteral elements: Element...) {
        self = Self(elements)
    }

    // MARK: - Indices

    public struct Index: Comparable {

        var _backingIndex: UInt32
        var isIndexGEQHead: Bool

        var backingIndex: Int { Int(_backingIndex) }

        internal init(backingIndex: Int, head: Int) {
            self._backingIndex = UInt32(backingIndex)
            self.isIndexGEQHead = backingIndex >= head
        }

        public static func == (l: Index, r: Index) -> Bool {
            l._backingIndex == r._backingIndex
        }

        public static func < (l: Index, r: Index) -> Bool {
            switch (l.isIndexGEQHead, r.isIndexGEQHead) {
                case (true, true), (false, false):
                    return l._backingIndex < r._backingIndex
                case (true, false):
                    return true
                case (false, true):
                    return false
            }
        }

    }

    internal func advance(_ index: inout Int, by offset: Int = 1) {
        index = (index &+ offset) & mask
    }

    internal mutating func advanceHead(by offset: Int = 1) {
        advance(&head, by: offset)
    }

    internal mutating func advanceTail(by offset: Int = 1) {
        advance(&tail, by: offset)
    }

    public mutating func append(_ element: Element) {


        backing[tail] = element
        advanceTail()

        if head == tail {
            doubleCapacity()
        }
    }

    internal mutating func doubleCapacity() {
        reserveCapacity(capacity * 2)
    }

    public mutating func reserveCapacity(_ newCapacity: Int) {
        let newCapacity = newCapacity.nextPowerOf2
        guard newCapacity > capacity else { return }

        var newBacking = ContiguousArray<Element?>()
        newBacking.reserveCapacity(newCapacity)

        if tail > head {
            newBacking.append(contentsOf: backing[head..<tail])
        } else {
            // we're wrapping around
            newBacking.append(contentsOf: backing[head..<backing.count])
            newBacking.append(contentsOf: backing[0..<tail])
        }

        let count = newBacking.count
        let nilCount = newCapacity - count
        newBacking.append(contentsOf: repeatElement(nil, count: nilCount))

        tail = count
        head = 0
        backing = newBacking

        assert(capacity == newCapacity)
    }

}

extension RingBuffer: MutableCollection {

    public var startIndex: Index {
        Index(backingIndex: head, head: head)
    }

    public var endIndex: Index {
        Index(backingIndex: tail, head: head)
    }

    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        Index(backingIndex: (i.backingIndex &+ distance) & mask,
              head: head)
    }

    public func index(after i: Index) -> Index {
        index(i, offsetBy: 1)
    }

    public func index(before i: Index) -> Index {
        index(i, offsetBy: -1)
    }

    public func distance(from start: Index, to end: Index) -> Int {
        switch (start.isIndexGEQHead, end.isIndexGEQHead) {
            case (true, true), (false, false):
                return end.backingIndex &- start.backingIndex
            case (true, false):
                return capacity &- (start.backingIndex &- end.backingIndex)
            case (false, true):
                return (end.backingIndex &- start.backingIndex) &- capacity
        }
    }

    public subscript(position: Int) -> Element {
        get { self[index(startIndex, offsetBy: position)] }
        set { self[index(startIndex, offsetBy: position)] = newValue }
    }

    public subscript(position: Index) -> Element {
        get { backing[position.backingIndex]! }
        set { backing[position.backingIndex] = newValue }
    }

    public subscript(bounds: Range<Index>) -> RingBuffer<Element> {
        precondition(distance(from: startIndex, to: bounds.lowerBound) >= 0)
        precondition(distance(from: bounds.upperBound, to: endIndex) >= 0)

        var newRing = self
        newRing.head = bounds.lowerBound.backingIndex
        newRing.tail = bounds.upperBound.backingIndex
        return newRing
    }

}

extension RingBuffer: RandomAccessCollection {

}

extension RingBuffer: RangeReplaceableCollection {

    public mutating func popFirst() -> Element? {
        isEmpty ? nil : removeFirst()
    }

    public mutating func popLast() -> Element? {
        isEmpty ? nil : removeLast()
    }

    @discardableResult
    public mutating func removeFirst() -> Element {
        defer { removeFirst(1) }
        return first!
    }

    @discardableResult
    public mutating func removeLast() -> Element {
        defer { removeLast(1) }
        return last!
    }

    public mutating func removeFirst(_ k: Int) {
        var index = head

        for _ in 0..<k {
            backing[index] = nil
            advance(&index)
        }

        head = index
    }

    public mutating func removeLast(_ k: Int) {
        var index = tail

        for _ in 0..<k {
            advance(&index, by: -1)
            backing[index] = nil
        }

        tail = index
    }

}


extension RingBuffer: Equatable where Element: Equatable {

    public static func == (l: Self, r: Self) -> Bool {
        l.count == r.count && zip(l, r).allSatisfy(==)
    }

}

extension RingBuffer: Hashable where Element: Hashable {

    public func hash(into hasher: inout Hasher) {
        for element in self {
            hasher.combine(element)
        }
    }

}

extension FixedWidthInteger {

    var nextPowerOf2: Self {
        if self == 0 {
            return 1
        }

        return 1 << (bitWidth - (self - 1).leadingZeroBitCount)
    }

}