//
//  TransducerIViewsInNavigationStack.swift
//  Oak
//
//  Created by Andreas Grosam on 11.05.25.
//

import SwiftUI

extension Timers.Views { enum NavigationStackViews {} }

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Timers.Views.NavigationStackViews {
    
    struct NavigationStackView: View {
        
        struct Timer: Identifiable, Hashable {
            let id: Int
        }

        @State private var timers: [Timer] = (1...10).map { Timer(id: $0) }
        
        var body: some View {
            NavigationStack {
                List(timers) { timer in
                    NavigationLink("\(timer.id)", value: timer)
                }
                .navigationDestination(for: Timer.self) { timer in
                    TransducerView(of: Timers.self, env: Timers.Env()) { state, send in
                        Timers.Views.TimerView(
                            state: state,
                            send: send
                        )
                        .onDisappear {
                            // When a Transducer view disappears and it has been
                            // initialised with parameter `terminateOnDisappear`
                            // set to `true` and its transducer is not terminated,
                            // the transducer view will forcibly terminate the
                            // transducer. This is in order to prevent memory
                            // leaks and to forcibly stop running tasks which
                            // otherwise would run forever. The transducer view
                            // will detect this situation forcibly terminating
                            // the transducer and log a corresponding warning.
                            //
                            // So, for a given use case we need to decide how to
                            // handle a user initiated dismissal. In this example,
                            // the view will disapear and also deallocate when
                            // when the user taps the back button. In order to
                            // explicitly terminate the transducer, we send a
                            // corresponding event to it. This will also silence
                            // the warning from the transducer view.
                            print("ContentView for Timer \(timer.id) disappeared. Sending event `terminate`")
                            send(.terminate)
                        }
                    }
                    .navigationTitle("Timer \(timer.id)")
                }
            }
        }
    }
    
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer List") {
    Timers.Views.NavigationStackViews.NavigationStackView()
}

