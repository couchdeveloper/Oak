/// A unique identifier which conforms to `Hashable` and `Sendable`.
///
/// This `ID` will be used to uniquely identify various components
/// in the FSM system, such as operations and effects.
///
/// This is not a type a user can create. It's public because it will be used as a
/// default argument (`nil`) for a generic parameter, `Optional<ID>.none`,
/// in APIs where a generic optional id with a type `(some Hashable & Sendable)?`
/// is required. A user always uses instances of concrete types, such as `Int`
/// or `String`. Only in cases were the id is not provided, the default value
/// will be used.
public struct ID: @unchecked Sendable, Hashable {
    private let wrapped: AnyHashable

    init(_ wrapped: some Hashable & Sendable) {
        self.wrapped = .init(wrapped)
    }
}
