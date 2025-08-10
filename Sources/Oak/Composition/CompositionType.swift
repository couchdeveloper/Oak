// Oak - CompositionType.swift
//
// Defines marker protocols for different composition strategies.

/// Base protocol for all composition type markers.
///
/// This protocol serves as a common base for all composition type markers,
/// allowing `CompositeTransducer` to constrain its `CompositionType` generic parameter.
public protocol CompositionType {}

/// Marker protocol for parallel composition.
///
/// In parallel composition:
/// - Both transducers receive their respective events independently
/// - Both produce outputs independently
/// - Outputs are combined when both transducers produce output simultaneously
/// - Either transducer can independently affect the composite output
public protocol ParallelComposition: CompositionType {}

/// Marker protocol for sequential composition.
///
/// In sequential composition:
/// - The first transducer processes events first
/// - Its output is transformed and fed as input to the second transducer
/// - The final output comes from the second transducer
public protocol SequentialComposition<InputType, OutputType>: CompositionType {
    /// The output type of the first transducer (TransducerA)
    associatedtype InputType
    
    /// The event type of the second transducer (TransducerB)
    associatedtype OutputType
    
    /// Transform from the first transducer's output to the second transducer's event
    static func transform(_ input: InputType) -> sending OutputType?
}

// Default implementations for the composition type markers
public struct DefaultParallelComposition: ParallelComposition {}

// DefaultSequentialComposition needs to be defined as a generic struct
// to support the transform method
public struct DefaultSequentialComposition<Input, Output>: SequentialComposition {
    public typealias InputType = Input
    public typealias OutputType = Output
    
    // Default implementation always returns nil
    public static func transform(_ input: Input) -> sending Output? {
        return nil
    }
}

/// Factory struct to create composition types
public struct TransducerComposition {
    /// Get the parallel composition type
    public static var parallel: DefaultParallelComposition.Type {
        DefaultParallelComposition.self
    }
    
    /// Get the sequential composition type with specified input and output types
    public static func sequential<Input, Output>() -> DefaultSequentialComposition<Input, Output>.Type {
        DefaultSequentialComposition<Input, Output>.self
    }
}
