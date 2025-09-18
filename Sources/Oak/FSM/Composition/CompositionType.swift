// Oak - CompositionType.swift
//
// Defines marker protocols for different composition strategies.

import Foundation

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
public protocol SequentialComposition: CompositionType {}

// Default implementations for the composition type markers
public struct DefaultParallelComposition: ParallelComposition {}
public struct DefaultSequentialComposition: SequentialComposition {}

/// Factory struct to create composition types
public struct TransducerComposition {
    /// Get the parallel composition type
    public static var parallel: DefaultParallelComposition.Type {
        DefaultParallelComposition.self
    }

    /// Get the sequential composition type
    public static var sequential: DefaultSequentialComposition.Type {
        DefaultSequentialComposition.self
    }
}
