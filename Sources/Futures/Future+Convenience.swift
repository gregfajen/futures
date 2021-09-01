//
//  Future+Convenience.swift
//  Created by Greg Fajen on 10/3/20.
//

import Foundation

public struct TimeoutError: Error {}

// MARK: - Operators

/// calls r iff l fails
public func ?? <T>(l: Future<T>, r: @escaping @autoclosure () -> Future<T>) -> Future<T> {
    l.flatMapError { _ in r() }
}

/// combines l and r, fails if either l or r fails
public func && <A, B>(l: Future<A>, r: Future<B>) -> Future<(A, B)> {
    l.and(r)
}

/// calls r iff l succeeds with nil. r is never called if l fails.
public func || <T>(l: Future<T?>, r: @escaping @autoclosure () -> Future<T>) -> Future<T> {
    l.flatMap {
        if let value = $0 {
            return .succeeded(value, on: l.queue)
        } else {
            return r()
        }
    }
}

public extension Future {
    @discardableResult
    @inlinable
    func whenSuccess(_ f: @escaping (Value) -> Void) -> Self {
        whenComplete {
            switch $0 {
            case let .success(value): f(value)
            case .failure: break
            }
        }
        return self
    }

    @discardableResult
    @inlinable
    func whenFailure(_ f: @escaping (Error) -> Void) -> Self {
        whenComplete {
            switch $0 {
            case .success: break
            case let .failure(error): f(error)
            }
        }
        return self
    }

    // MARK: - Creation

    static func succeeded<Value>(_ value: Value, on queue: FutureQueue = .background) -> Future<Value> {
        let p = Promise<Value>(on: queue)
        p.succeed(value)
        return p.future
    }

    static func failed<Value>(_ error: Error, on queue: FutureQueue = .background) -> Future<Value> {
        let p = Promise<Value>(on: queue)
        p.fail(error)
        return p.future
    }

    // Combining

    /// combines l and r, fails if either l or r fails
    @inlinable
    func and<T>(_ other: Future<T>) -> Future<(Value, T)> {
        let promise = Promise<(Value, T)>(on: queue)
        var a: Value?
        var b: T?

        whenComplete {
            switch self._result! {
            case let .success(x):
                if let y = b {
                    return promise._complete(.success((x, y)))
                } else {
                    a = x
                    return .empty
                }

            case let .failure(error):
                return promise._complete(.failure(error))
            }
        }

        other.hop(to: queue).whenComplete {
            switch other._result! {
            case let .success(y):
                if let x = a {
                    return promise._complete(.success((x, y)))
                } else {
                    b = y
                    return .empty
                }

            case let .failure(error):
                return promise._complete(.failure(error))
            }
        }

        return promise.future
    }

    // MARK: - Timeouts

    func timeout(after interval: TimeInterval) -> Future {
        let promise = Promise<Value>(on: queue)
        let future = promise.future

        cascade(to: promise)

        queue.asyncAfter(deadline: .now() + interval) {
            if !future._result.exists {
                promise.fail(TimeoutError())
            }
        }

        return future
    }

    // MARK: - Debugging

    func log() -> Future<Value> {
        return mapResult { result -> Value in
            switch result {
            case let .success(value):
                print("value: \(value)")
                return value

            case let .failure(error):
                print("error: \(error)")
                throw error
            }
        }
    }
}

// MARK: - Optionals

public extension Future where Value: OptionalProtocol {
    func unwrap(orThrow error: @escaping @autoclosure () -> Error = FutureError("found nil")) -> Future<Value.Wrapped> {
        map {
            guard let value = $0.asOptional else {
                throw error()
            }

            return value
        }
    }
}

// MARK: - Sequences

public extension Future where Value: Collection {
    var first: Future<Value.Element> {
        map { collection -> Value.Element in
            guard let first = collection.first else {
                throw FutureError("tried to get first element of empty collection")
            }

            return first
        }
    }
}
