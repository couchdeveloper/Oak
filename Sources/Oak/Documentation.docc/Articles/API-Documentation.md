# Oak

@Metadata {
   @Available("iOS", introduced: "15.0")   
   @Available("iPadOS", introduced: "15.0")   
   @Available("macOS", introduced: "12.0")   
   @Available("macCatalyst", introduced: "15.0")   
   @Available("tvOS", introduced: "12.0")
   @Available("watchOS", introduced: "8.0") 
}

This page organizes the Oak API by functional area. Use it as the entry point to the full symbol reference.

## Topics

### Core Transducer Protocols

- ``Transducer``
- ``EffectTransducer``
- ``BaseTransducer``
- ``TransducerProxy``

### Effect System

- ``Effect``

### Input and Output

- ``Proxy``
- ``BufferedTransducerInput``
- ``Subject``
- ``Callback``

Use the `Proxy.Input` handle returned by ``Proxy`` to forward events through types that conform to ``BufferedTransducerInput``, and combine it with ``Subject`` or ``Callback`` when bridging between transducers.

### SwiftUI Integration

- ``TransducerView``
- ``ObservableTransducer``
- ``TransducerActor``

### State Management Utilities

- ``Terminable``
- ``NonTerminal``

## Complete API Reference

This page organizes the most commonly used APIs by functional area. For the complete alphabetical index of all Oak symbols, navigate to the main Oak module documentation from the top-level navigation.