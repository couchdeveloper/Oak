
/// A type which observes a completion notification.
///
/// A completion value is used as a parameter and set by the caller when
/// using a transducer actor.  When the transducer completes, the completion
/// value acts accordingly, usually calling a closure that has been providedy
/// in the completion's initialiser.
///
/// Types which conform to `TransducerActor` should implement
/// a concrete type which fulfills the requirements of their implemention.
///
/// > Note: The corresponding `Completion` type is already implemented
/// for `TransducerView` and `ObservableTransducer`.
///
/// ## Example
///
/// The example below shows an implementation for a transducer actor which
/// is runnnig on the MainActor, such as an Observable or a SwiftUI View.
///
/// ```swift
/// public struct Completion: @MainActor Oak.Completable {
///     public typealias Value = Output
///     public typealias Failure = Error
///
///     let f: (Result<Value, Failure>) -> Void
///
///     public init(
///         _ onCompletion: @escaping(
///             Result<Value, Failure>
///         ) -> Void
///     ) {
///         f = onCompletion
///     }
///     public func completed(
///         with result: Result<Value, Failure>
///     ) {
///         f(result)
///     }
///
///     func before(
///         g: @escaping (
///             Result<Value, Failure>
///         ) -> Result<Value, Failure>
///     ) -> Self {
///         .init { result in
///             self.f(g(result))
///         }
///     }
/// }
///```
public protocol Completable<Value, Failure> {
    associatedtype Value
    associatedtype Failure: Error

    func completed(with: Result<Value, Failure>)
}
