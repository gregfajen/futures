//
//  Future+Reduction.swift
//  Created by Greg Fajen on 11/30/19.
//

import Foundation

public extension Future {
    static func reducing<Value>(_ futures: [Future<Value>],
                                on optionalQueue: FutureQueue? = nil) -> Future<[Value]>
    {
        guard let first = futures.first else {
            return .succeeded([], on: optionalQueue ?? .background)
        }

        let queue = optionalQueue ?? first.queue
        let promise = Promise<[Value]>(on: queue)

        var remaining = futures.count
        var results = [Value?](repeating: nil, count: remaining)

        var hasFailed = false

        futures
            .map { $0.hop(to: queue) }
            .enumerated()
            .forEach { i, future in
                future.whenComplete {
                    guard !hasFailed else { return .empty }

                    switch future._result! {
                    case let .failure(error):
                        hasFailed = true
                        return promise._complete(.failure(error))

                    case let .success(value):
                        results[i] = value
                        remaining -= 1

                        if remaining == 0 {
                            return promise._complete(.success(results.compact))
                        } else {
                            return .empty
                        }
                    }
                }
            }

        return promise.future
    }
}

public extension Sequence where Element: AnyFuture {
    var reduced: Future<[Element.Value]> {
        // this force-cast will never fail but is needed for Swift to typecheck this
        .reducing(Array(self) as! [Future<Element.Value>])
    }
}

public protocol AnyFuture {
    associatedtype Value
}

extension Future: AnyFuture {}
