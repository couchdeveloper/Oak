/// A transducer error type that conforms to `Swift.Error` and `Equatable`.
/// 
/// It represents various errors that can occur in a transducer system. 
/// - `proxyAlreadyInUse`: Indicates that a proxy is already in use.
/// - `noOutputProduced`: Indicates that no output was produced by the transducer.
/// - `cancelled`: Indicates that the transducer operation was cancelled via its proxy, i.e. `proxy.cancel()`.
/// 
/// This error will be thrown from the `run` function.
public enum TransducerError: Swift.Error, Equatable {
    case proxyAlreadyInUse
    case noOutputProduced
    case cancelled
}
