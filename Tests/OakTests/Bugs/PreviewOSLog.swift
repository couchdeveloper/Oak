//
//  PreviewOSLog.swift
//  Oak
//
//  Created by Andreas Grosam on 10.05.25.
//

#if false

import OSLog
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .task {
            logger.info("Hallo")
        }
    }
}
 
#Preview {
    ContentView()
}
#endif
