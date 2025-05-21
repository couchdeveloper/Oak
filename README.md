# Oak

Oak brings the power of finite state machines (FSM) to your projects. 

The Oak library is primarily intended to implement the typical frontend patterns and artefacts, like ViewModels, Interactors, etc., but it is not limited to this.


## Overview

FSMs are utilized to develop systems characterized by discrete and sequential behavior. The correctness of these systems is guaranteed by their mathematical framework, while their strength lies in their ability to be composed together.

This makes them an ideal candidate to implement the logic in user interfaces, but they can effectively address a wide range of problems. 


## Why Oak

Focuses on the principles that matter:

- improves static reasonability
- uses pure functions
- is event driven
- is unidirectional
- favours coding style with high LoB

## Table of Contents

## Theory and Concepts

Defining the state, input (Event) and the transition function of a FSM: 

```swift 
enum Counter {
    enum State {
        case start
        case idle(counter: Int)
        case terminated(finalValue: Int)
    }
    
    enum Event {
        case start(initialValue: Int)
        case countUp
        case countDown
        case terminate
    }
    
    static func transition(_ state: inout State, event: Event) {
        defer {
            print("event: \(event), state: \(state)")
        }
        switch (event, state) {
        case (.start(let initialValue), .start):
            state = .idle(counter: initialValue)
            return
        case (.countUp, .idle(counter: let counter)):
            state = .idle(counter: counter + 1)
            return
        case (.countDown, .idle(counter: let counter)):
            state = .idle(counter: counter - 1)
            return
        case (.terminate, .idle(counter: let counter)):
            state = .terminated(finalValue: counter)
            return
            
        case (.terminate, .start):
            return
        case (.countDown, .start):
            return
        case (.countUp, .start):
            return
        case (.start, .idle):
            return
        case (_, .terminated):
            return
        }
    }
}
```

A SwiftUI view can use this in this way: 

```swift
import SwiftUI

extension Counter { enum Views {} }

extension Counter.State {
    var counter: Int? {
        switch self {
        case .idle(counter: let value):
            value
        case .terminated(finalValue: let value):
            value
        case .start:
            nil
        }
    }
}

extension Counter.Views {
 
    struct ContentView: View {
        @State private var state: Counter.State = .idle(counter: 0)
        
        var body: some View {
            let counter = state.counter ?? 0
            VStack {
                Text("\(counter)")
                    .font(.largeTitle)
                    .padding()
                
                HStack {
                    Button {
                        send(.countUp)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .padding()
                    Button {
                        send(.countDown)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .padding()
                }
            }
        }
        
        func send(_ event: Counter.Event) {
            Counter.transition(&state, event: event)
        }
    }
}


#Preview {
    Counter.Views.ContentView()
}
``` 

## Quick Start

### Installation

### Usage



## Examples

## Contributing

## Credits

## License
