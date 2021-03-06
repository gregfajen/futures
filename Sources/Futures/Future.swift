//
//  Future.swift
//  Created by Greg Fajen on 12/30/19.
//

public class Future<Value> {

    public typealias R = Result<Value, Error>
    @usableFromInline typealias Callback = CallbackList.Element

    public let queue: FutureQueue

    @usableFromInline var _result: R?
    @inlinable public var result: R? { _result }
    @inlinable public var exists: Bool { _result.exists }
    @usableFromInline var callbacks = CallbackList()

    @inlinable public var value: Value? { _result?.success }
    @inlinable public var error: Error? { _result?.failure }

    fileprivate init(on queue: FutureQueue) {
        self.queue = queue
    }

    public convenience init(_ other: Future<Value>) {
        self.init(on: other.queue)
        other.whenComplete {
            self._complete(other._result!)
        }
    }

    public convenience init(_ other: Promise<Value>) {
        self.init(other.future)
    }

    public convenience init(on queue: FutureQueue,
                            _ closure: @escaping () throws -> Value)
    {
        self.init(queue.submit(closure))
    }

    public convenience init(on queue: FutureQueue,
                            _ closure: @escaping (Promise<Value>) throws -> Void)
    {
        let promise = Promise<Value>(on: queue)

        queue.async {
            do {
                try closure(promise)
            } catch {
                promise.fail(error)
            }
        }

        self.init(promise.future)
    }

    @inlinable func complete(_ result: R) {
        if queue.isOnQueue {
            _complete(result).run()
        } else {
            queue.async {
                self._complete(result).run()
            }
        }
    }

    @inlinable func _complete(_ result: R) -> CallbackList {
        queue.preconditionOnQueue()
        if _result.exists { return .empty }

        _result = result

        let list = callbacks
        callbacks = .empty
        return list
    }

    @inlinable func whenComplete(_ callback: @escaping () -> CallbackList) {
        if queue.isOnQueue {
            _addCallback(callback).run()
        } else {
            queue.async {
                self._addCallback(callback).run()
            }
        }
    }

    @inlinable func _addCallback(_ callback: @escaping Callback) -> CallbackList {
        queue.preconditionOnQueue()

        if _result.exists {
            return callback()
        } else {
            callbacks.append(callback)
            return .empty
        }
    }

    @inlinable
    public func cascade(to promise: Promise<Value>) {
        whenComplete {
            if promise.future.queue.isOnQueue {
                return promise._complete(self._result!)
            } else {
                promise.complete(self._result!)
                return .empty
            }
        }
    }

    @inlinable
    public func whenComplete(_ block: @escaping (R) -> Void) {
        whenComplete {
            block(self._result!)
            return .empty
        }
    }

    // MARK: - Map

    @inlinable
    public func map<T>(_ callback: @escaping (Value) throws -> (T)) -> Future<T> {
        let promise = Promise<T>(on: queue)

        whenComplete {
            switch self._result! {
            case let .success(value):
                do {
                    let newValue = try callback(value)
                    return promise._complete(.success(newValue))
                } catch {
                    return promise._complete(.failure(error))
                }

            case let .failure(error):
                return promise._complete(.failure(error))
            }
        }

        return promise.future
    }

    @inlinable
    public func mapResult<T>(_ callback: @escaping (R) throws -> T) -> Future<T> {
        let promise = Promise<T>(on: queue)

        whenComplete {
            do {
                let value = try callback(self._result!)
                return promise._complete(.success(value))
            } catch {
                return promise._complete(.failure(error))
            }
        }

        return promise.future
    }

    @inlinable
    public func mapError(_ f: @escaping (Error) throws -> Value) -> Future<Value> {
        mapResult { result -> Value in
            switch result {
            case let .success(value): return value
            case let .failure(error):
                do {
                    return try f(error)
                } catch let e {
                    throw e
                }
            }
        }
    }

    // MARK: - Flat Map

    @inlinable
    public func flatMap<T>(_ callback: @escaping (Value) throws -> Future<T>) -> Future<T> {
        let promise = Promise<T>(on: queue)

        whenComplete {
            switch self._result! {
            case let .success(value):
                do {
                    let newFuture = try callback(value)
                    if newFuture.queue.isOnQueue {
                        return newFuture._addCallback {
                            promise._complete(newFuture._result!)
                        }
                    } else {
                        newFuture.cascade(to: promise)
                        return .empty
                    }
                } catch {
                    return promise._complete(.failure(error))
                }

            case let .failure(error):
                return promise._complete(.failure(error))
            }
        }

        return promise.future
    }

    @inlinable
    public func flatMapResult<T>(_ callback: @escaping (R) -> Future<T>) -> Future<T> {
        let promise = Promise<T>(on: queue)

        whenComplete {
            let newFuture = callback(self._result!)
            if newFuture.queue.isOnQueue {
                return newFuture._addCallback {
                    promise._complete(newFuture._result!)
                }
            } else {
                newFuture.cascade(to: promise)
                return .empty
            }
        }

        return promise.future
    }

    @inlinable
    public func flatMapError(_ callback: @escaping (Error) -> Future<Value>) -> Future<Value> {
        flatMapResult { result -> Future<Value> in
            switch result {
            case let .success(value): return .succeeded(value, on: self.queue)
            case let .failure(error): return callback(error)
            }
        }
    }
}

// MARK: - Promise

/// a tiny wrapper around `Future` to allow us to complete it
/// once we get rid of the `Promise`s, the `Future` becomes immutable
/// generally, you keep promises to yourself and pass around futures
/// the preferred way of creating futures if you have one already is to use a function like flatMap
public struct Promise<Value> {
    public let future: Future<Value>

    public typealias R = Result<Value, Error>

    public init(on queue: FutureQueue) {
        future = .init(on: queue)
    }

    public func succeed(_ value: Value) {
        complete(.success(value))
    }

    public func fail(_ error: Error) {
        complete(.failure(error))
    }

    public func complete(_ result: R) {
        future.complete(result)
    }

    @inlinable func _complete(_ result: R) -> CallbackList {
        future._complete(result)
    }
}

// MARK: - Result Extension

public extension Result {
    var success: Success? {
        switch self {
        case let .success(s): return s
        case .failure: return nil
        }
    }

    var failure: Failure? {
        switch self {
        case .success: return nil
        case let .failure(f): return f
        }
    }
}
