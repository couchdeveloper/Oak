//
//  ContentInNavigationStack.swift
//  Oak
//
//  Created by Andreas Grosam on 11.05.25.
//
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Timers.Views {
    
    struct NavigationStackView: View {
        var body: some View {
            NavigationStack {
                TransducerView(of: Timers.self, env: Timers.Env()) { state, send in
                    TimerView(
                        state: state,
                        send: send
                    )
                }
                .onDisappear {
                    print("TransducerView 'Timers': onDisappear")
                }
                .navigationTitle(Text("Timers"))
            }
        }
    }
}


@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview {
    Timers.Views.NavigationStackView()
}
