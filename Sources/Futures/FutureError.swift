//
//  FutureError.swift
//  Created by Greg Fajen on 3/29/21.
//

import Foundation

public struct FutureError: LocalizedError {
    
    public let message: String
    public var errorDescription: String? { message }
    
    public init(_ message: String) {
        self.message = message
    }
    
}
