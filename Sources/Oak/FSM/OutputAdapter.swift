// Oak - OutputAdapter.swift
//
// Defines the adapter for transforming outputs between transducers.

import Foundation

/// Helper type to adapt outputs between transducers.
///
/// OutputAdapter provides a mechanism to transform outputs from one type to another,
/// which is essential for composite transducers where component outputs need to be 
/// converted to the composite output type.
public struct OutputAdapter {
    /// The transformation function that converts from any type to the desired output type
    private let transformClosure: (Any) -> Any?
    
    /// Initializes a new output adapter with a transformation function
    /// - Parameter transform: The function that transforms inputs to outputs
    public init<I, O>(transform: @escaping (I) -> O?) {
        self.transformClosure = { input in
            guard let typedInput = input as? I else { return nil }
            return transform(typedInput)
        }
    }
    
    /// Transforms a value from one type to another
    /// - Parameter value: The value to transform
    /// - Returns: The transformed value, or nil if transformation failed
    public func transform(_ value: Any) -> Any? {
        return transformClosure(value)
    }
}
