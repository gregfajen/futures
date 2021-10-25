//
//  OptionalProtocol.swift
//  Created by Greg Fajen on 3/29/21.
//

import Foundation

public protocol OptionalProtocol {
    associatedtype Wrapped

    var asOptional: Wrapped? { get }

    static var none: Self { get }

}

extension Optional: OptionalProtocol {
    public var asOptional: Wrapped? { self }
}

public extension Optional {
    var exists: Bool { self != nil }
}

public extension Sequence where Element: OptionalProtocol {
    var compact: [Element.Wrapped] { compactMap(\.asOptional) }
}
