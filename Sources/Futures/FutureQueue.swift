//
//  FutureLoop.swift
//  Created by Greg Fajen on 11/10/20.
//

import Foundation

/// a tiny wrapper around `DispatchQueue`s that lets us check to see if we are currently on a queue
/// and ensures that the underlying `DispatchQueue` is NOT a concurrent queue
public class FutureQueue: Equatable {
    let ID = UUID()
    public let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<UUID>()

    public static let main = FutureQueue(.main)
    public static let background = FutureQueue("FutureQueue.background")

    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: queueKey) == ID
    }

    private init(_ queue: DispatchQueue) {
        self.queue = queue
        queue.setSpecific(key: queueKey, value: ID)
    }

    public convenience init(_ label: String,
                            qos: DispatchQoS = .default)
    {
        let queue = DispatchQueue(label: label,
                                  qos: qos,
                                  autoreleaseFrequency: .workItem)
        self.init(queue)
    }

    public func preconditionOnQueue() {
        precondition(isOnQueue)
    }

    public func preconditionNotOnQueue() {
        precondition(!isOnQueue)
    }

    public static func == (lhs: FutureQueue, rhs: FutureQueue) -> Bool {
        lhs === rhs
    }
}

public extension FutureQueue {
    func sync<T>(_ closure: () -> T) -> T {
        queue.sync(execute: closure)
    }

    func async(_ closure: @escaping () -> Void) {
        queue.async(execute: closure)
    }

    func asyncAfter(deadline: DispatchTime, _ closure: @escaping () -> Void) {
        queue.asyncAfter(deadline: deadline, execute: closure)
    }

    func future<T>(_ closure: @escaping () throws -> T) -> Future<T> {
        submit(closure)
    }

    func submit<T>(_ closure: @escaping () throws -> T) -> Future<T> {
        if isOnQueue {
            do {
                return .succeeded(try closure(), on: self)
            } catch {
                return .failed(error, on: self)
            }
        }

        let promise = Promise<T>(on: self)

        async {
            do {
                promise.succeed(try closure())
            } catch {
                promise.fail(error)
            }
        }

        return promise.future
    }

    func flatSubmit<T>(_ closure: @escaping () throws -> Future<T>) -> Future<T> {
        submit(closure).flatMap { $0 }
    }
}

public extension Future {
    func hop(to queue: FutureQueue) -> Future<Value> {
        if self.queue == queue { return self }

        let promise = Promise<Value>(on: queue)
        cascade(to: promise)
        return promise.future
    }
}
