# Oak

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

### Full Reference

For the complete API index, see the module reference: ``Oak``.