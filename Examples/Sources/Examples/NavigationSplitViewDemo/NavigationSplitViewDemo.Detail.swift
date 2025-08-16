//
//  NavigationSplitView.Detail.swift
//  Examples
//
//  Created by Andreas Grosam on 12.08.25.
//

import Foundation
import Oak

extension NavigationSplitViewDemo.Detail /*: EffectTransducer */ {

    // MARK: Model
    // The item model for the detail view.
    // 
    // The detail view is showing a ToDo item as its content.
    // Note, that an `Item` in the `Detail` namespace is different
    // from the `Item` in the `List` namespace.
    struct Item: Identifiable, Equatable {
        enum State {
            case open
            case closed
        }
        
        let id: UUID
        let creationDate: Date
        let dueDate: Date?
        let titel: String
        let description: String
    }
    
}

extension NavigationSplitViewDemo.Detail: EffectTransducer {
    
    typealias ItemID = NavigationSplitViewDemo.List.Item.ID

    struct Env {
        var loadItem: (ItemID) async throws -> Item
    }
    
    enum State: NonTerminal {
        case start(itemId: ItemID)
        case loading(itemId: ItemID)
        case idle(Item)
        case loadError(Swift.Error, itemId: ItemID)
    }
    
    enum Event {
        case start
        case serviceItem(Item)
        case serviceError(Swift.Error, for: ItemID)
    }
    
    enum Output {
        case none
        case loadSuccess(itemId: Item)
        case loadFailed(error: Swift.Error, itemId: ItemID)
        case message(String)
    }
    
    static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
        switch (state, event) {
        case (.start(let itemID), .start):
            state = .loading(itemId: itemID)
            return (Effects.loadItem(itemId: itemID), .message("Loading item..."))

        case (.loading(_), .serviceItem(let item)):
            state = .idle(item)
            return (nil, .loadSuccess(itemId: item))
            
        case (.loading(let itemId), .serviceError(let error, let errorItemId)) where itemId == errorItemId:
            state = .loadError(error, itemId: itemId)
            return (nil, .loadFailed(error: error, itemId: itemId))
            
        case (.idle(let item), .start):
            // Reload the same item
            let itemId = item.id
            state = .loading(itemId: itemId)
            return (Effects.loadItem(itemId: itemId), .message("Reloading item..."))
            
        case (.loadError(_, let itemId), .start):
            // Retry loading - now we have the itemId available from the error state
            state = .loading(itemId: itemId)
            return (Effects.loadItem(itemId: itemId), .message("Retrying to load item..."))
            
        default:
            // Ignore unexpected event/state combinations
            return (nil, .none)
        }
    }
}

extension NavigationSplitViewDemo.Detail.Effects {
    
    typealias Effect = NavigationSplitViewDemo.Detail.Effect
    typealias ItemID = NavigationSplitViewDemo.List.Item.ID
    
    static func loadItem(itemId: ItemID) -> Effect {
        Effect(id: "loadItem") { env, input, actor in
            do {
                let item = try await env.loadItem(itemId)
                try input.send(.serviceItem(item))
            } catch {
                try input.send(.serviceError(error, for: itemId))
            }
        }
    }
}

// MARK: - Views

import SwiftUI

// MARK: - ENV
 extension EnvironmentValues {
    @Entry var navigationSplitViewDemoDetailEnv: NavigationSplitViewDemo.Detail.Env = .init(loadItem: { _ in
        try await Task.sleep(for: .seconds(1))
        return NavigationSplitViewDemo.Detail.Item(
            id: UUID(),
            creationDate: Date(),
            dueDate: nil,
            titel: "Item \(UUID())",
            description: "This is a description for item \(UUID())."
        )
    })
}

// MARK: - State accessor helpers
extension NavigationSplitViewDemo.Detail.State {
    typealias Item = NavigationSplitViewDemo.Detail.Item
    
    var item: Item? {
        switch self {
        case .idle(let item):
            return item
        default:
            return nil
        }
    }

    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    var error: Swift.Error? {
        switch self {
        case .loadError(let error, _):
            return error
        default:
            return nil
        }
    }
}

// MARK: - Views
extension NavigationSplitViewDemo.Detail.Views {
    
    typealias Item = NavigationSplitViewDemo.Detail.Item
    typealias Output = NavigationSplitViewDemo.Detail.Output
    typealias Transducer = NavigationSplitViewDemo.Detail

    struct ContentView: View {
        @State private var state: NavigationSplitViewDemo.Detail.State? = nil
        @State private var proxy: NavigationSplitViewDemo.Detail.Proxy = .init()
        @Environment(\.navigationSplitViewDemoDetailEnv) private var env
        let output: Callback<Output>

        init(itemId: Item.ID? = nil, output: Callback<Output>) {
            self.output = output
            if let itemId = itemId {
                self._state = State(initialValue: .start(itemId: itemId))
            } else {
                self._state = State(initialValue: nil)
            }
        }

        var body: some View {
            Group {
                if let state = state {
                    TransducerView(
                        of: Transducer.self,
                        initialState: .constant(state),
                        proxy: proxy,
                        env: env,
                        output: output
                    ) { state, input in
                        ItemView(
                            item: state.item, 
                            isLoading: state.isLoading, 
                            error: state.error
                        )
                    }
                } else {
                    ItemView(
                        item: nil,
                        isLoading: false,
                        error: nil
                    )
                }
            }
        }
    }

    struct ItemView: View {
        let item: Item?
        let isLoading: Bool
        let error: Swift.Error?
        
        init(item: Item? = nil, isLoading: Bool = false, error: Swift.Error? = nil) {
            self.item = item
            self.isLoading = isLoading
            self.error = error
        }
        
        var body: some View {
            Group {
                if isLoading {
                    LoadingView()
                } else if let error = error {
                    ErrorView(error: error)
                } else if let item = item {
                    ItemContentView(item: item)
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading item...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    struct ErrorView: View {
        let error: Swift.Error
        
        var body: some View {
            ContentUnavailableView(
                "Unable to Load Item",
                systemImage: "exclamationmark.triangle",
                description: Text("An error occurred while loading the item.\n\(error.localizedDescription)")
            )
        }
    }
    
    struct ItemContentView: View {
        let item: Item
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.titel)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Created \(item.creationDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Description Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                    }
                    
                    // Due Date Section (if available)
                    if let dueDate = item.dueDate {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Due Date")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.accentColor)
                                Text(dueDate, style: .date)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding()
            }
        }
    }
    
    struct EmptyStateView: View {
        var body: some View {
            ContentUnavailableView(
                "No Item Selected",
                systemImage: "doc.text",
                description: Text("Select an item from the list to view its details.")
            )
        }
    }
    
}
