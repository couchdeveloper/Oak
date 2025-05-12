//
//  ContentView.swift
//  TimersTabViewDemo
//
//  Created by Andreas Grosam on 12.05.25.
//

import SwiftUI
import Oak

struct ContentView: View {
    struct Timer: Identifiable, Hashable {
        let id: Int
    }

    @State private var timers: [Timer] = (1...10).map { Timer(id: $0) }

    var body: some View {
        TabView {
            TimerView(id: 1)
            .tabItem {
                Label("One", systemImage: "star")
            }

            TimerView(id: 1)
            .tabItem {
                Label("Two", systemImage: "circle")
            }
            
            ListView()
            .tabItem {
                Label("List", systemImage: "list.triangle")
            }
        }
    }
}

struct TimerView: View {
    let id: Int
    
    var body: some View {
        // Here in this example, when running in a tab view, we want the
        // transducer to continue to count, even when switching tabs.
        //
        // In order to let the transducer run we need to set parameter
        // `terminateOnDisappear` to `false`. This will prevent the transducer
        // view to forcibly terminate the transducer when it disappears. Still,
        // we can choose to terminate the transducer programmatically via
        // sending it an event where the transducer will reach a terminal state.
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
    }
    
}

struct ListView: View {
    var body: some View {
        // Timers will be cancelld when the tab view
        // switches. A view will actually receive the
        // `onDisappear` modifier, when we switch to another
        // tab. This also cancells any running task started
        // with the `task` modifier. This has some
        // consequences:
        //
        // The transducers in the detail view of the
        // NavigationStackView are configured to terminate
        // when the view disappears. So, this happens when
        // we navigate back (we could easily change it
        // so that the transducer will continue to run
        // when the view disappears, though).
        //
        // We also should see a "done" when switching tabs
        // back and forth, when showing the detail view.
        // However, it's a matter of the use case if we
        // want this to happoen or if we want the transducer
        // to continue to run. For a modal view for example,
        // we may want to bind the transducer's lifetime
        // to the apprearance life-cycle of the view.
        // This would intentially cause an error when we
        // try to dismiss the modal view and the transducer
        // is not yet finished: we want the logic to be
        // the authority when a view is done or not.
        Timers.Views.NavigationStackView()
    }
}


// MARK: - Preiviews

#Preview {
    ContentView()
}
