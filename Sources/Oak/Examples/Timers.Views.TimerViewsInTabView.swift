//
//  Timers.Views.TimerViewsInTabView.swift
//  Oak
//
//  Created by Andreas Grosam on 11.05.25.
//

import SwiftUI

extension Timers.Views { enum TabViewViews {} }

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Timers.Views.TabViewViews {
    
    struct ContentView: View {
        let id: Int
        
        var body: some View {
            // When running in a tab view, we don't want the transducer to stop
            // when we switch tabs. In order to let the transducer run we need to
            // set parameter `terminateOnDisappear` to `false`. This will prevent
            // the transducer view to forcibly terminate the transducer when it
            // disappears. Still, we can choose to terminate the transducer
            // programmatically via sending it an event where the transducer
            // will reach a terminal state.
            TransducerView(
                of: Timers.self,
                env: Timers.Env(),
                terminateOnDisappear: false
            ) { state, send in
                Timers.Views.TimerView(
                    state: state,
                    send: send
                )
            }
            .navigationTitle("Timer \(id)")
        }
        
    }
    
    struct TabViewView: View {
        
        struct Timer: Identifiable, Hashable {
            let id: Int
        }

        @State private var timers: [Timer] = (1...10).map { Timer(id: $0) }
        
        var body: some View {
            TabView {
                ContentView(id: 1)
                    .tabItem {
                        Label("One", systemImage: "star")
                    }
                ContentView(id: 1)
                    .tabItem {
                        Label("Two", systemImage: "circle")
                    }
            }
        }
    }
    
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer List") {
    Timers.Views.TabViewViews.TabViewView()
}

