//
//  CallbackList.swift
//  Created by Greg Fajen on 11/10/20.
//

import Foundation
import CircularBuffer

// this file is largely adapted from https://github.com/apple/swift-nio/blob/main/Sources/NIO/EventLoopFuture.swift
// it's essentially an array of closures, but heavily optimized for containing zero or one closure
// the closures themselves take no arguments but return another callback list to be iterated through
// introducing this CallbackList (vs just naïvely using GCD's `async` calls) resulted in a massive performance boost

@usableFromInline
struct CallbackList {
    
    @usableFromInline typealias Element = () -> CallbackList
    
    // these are separated so that we only allocate an array for two or more callbacks
    // 99% of the time we don't even have a single callback
    @usableFromInline var firstCallback: Element?
    @usableFromInline var moreCallbacks: ContiguousArray<Element>?
    
    @inlinable static var empty: CallbackList { CallbackList() }
    
    @inlinable init() { }
    
    @inlinable
    mutating func append(_ callback: @escaping Element) {
        if firstCallback.exists {
            if moreCallbacks.exists {
                moreCallbacks!.append(callback)
            } else {
                moreCallbacks = [callback]
            }
        } else {
            firstCallback = callback
        }
    }
    
    @inlinable
    var circularBuffer: CircularBuffer<Element> {
        var buffer = CircularBuffer<Element>.init()
        appendAllCallbacks(to: &buffer)
        return buffer
    }
    
    @inlinable
    func appendAllCallbacks(to buffer: inout CircularBuffer<Element>) {
        guard let first = firstCallback else { return }
        
        buffer.reserveCapacity(buffer.count + 1 + (moreCallbacks?.count ?? 0))
        
        buffer.append(first)
        
        if let more = moreCallbacks {
            buffer.append(contentsOf: more)
        }
    }
    
    @inlinable
    func run() {
        guard var callback = firstCallback else { return }
        
        guard moreCallbacks.exists else {
            while true {
                let list = callback()
                switch (list.firstCallback, list.moreCallbacks) {
                    case (.none, _): // if first is nil, more is always nil
                        return
                        
                    case (.some(let first), .none):
                        callback = first
                        
                    case (.some, .some):
                        var pendingCallbacks = list.circularBuffer
                        while let callback = pendingCallbacks.popFirst() {
                            let evenMoreCallbacks = callback()
                            evenMoreCallbacks.appendAllCallbacks(to: &pendingCallbacks)
                        }
                        
                        return
                }
            }
        }
        
        var pendingCallbacks = circularBuffer
        while let callback = pendingCallbacks.popFirst() {
            let evenMoreCallbacks = callback()
            evenMoreCallbacks.appendAllCallbacks(to: &pendingCallbacks)
        }
    }
    
}
