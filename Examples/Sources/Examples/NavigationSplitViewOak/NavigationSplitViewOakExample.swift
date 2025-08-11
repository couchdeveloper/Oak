// NavigationSplitViewOakExample.swift
//
// Demonstrates using Oak with SwiftUI's NavigationSplitView.

import Foundation
import Oak

enum NavigationSplitViewDemo {

    enum Sheet {
        struct Edit {
            let item: Item
        }
        struct Create {
            let item: Item
        }
        struct Delete {
            let item: Item
        }

        case create(Create)
        case edit(Edit)
        case delete(Delete)
    }

    enum Main {
        typealias Sheet = NavigationSplitViewDemo.Sheet
    }

    enum Detail {
        typealias Sheet = NavigationSplitViewDemo.Sheet
        // typealias State = NavigationSplitViewUtilities.State<Item, Sheet>
    }
}

// MARK: - Model

extension NavigationSplitViewDemo {

    struct Item: Identifiable, Hashable {
        let id: UUID
        let name: String
        let detail: String
    }

}
// MARK: - Main List Transducer

extension NavigationSplitViewDemo.Main: EffectTransducer {

    struct Context {
        let input: Input
    }

    struct Data {
        enum Sortorder {
            enum Direction { case asc, desc }
            case byCreationDate(Direction)
            case byDueDate(Direction)
        }

        var items: [Item] = []
        var sortOrder: Sortorder = .byCreationDate(.asc)
        var current: Item.ID? = nil  // selected
    }

    typealias Item = NavigationSplitViewDemo.Item

    // This is an id for a certain kind of action/operation
    // that will be executed as an effect, and which may fail
    // and return an error. The ID will be used to identify
    // the managed task and may also help the transducer to
    // identify which kind of action it was that caused the
    // error (but not which instance of this action it was).
    enum ActionID: Equatable, Identifiable, Hashable {
        case loadItems
        case createItem
        case deleteItem
        case updateItem
        
        var id: Self { self }
    }
    
    struct Error {
        init(_ error: Swift.Error, actionId: ActionID? = nil) {
            self.error = error
            self.actionId = actionId
        }
        var error: Swift.Error
        var actionId: ActionID? = nil
    }

    typealias State = NavigationSplitViewUtilities.State<Data, Sheet, Error, Context>

    enum Event {
        case start
        case initContext(Context)
        case intentLoadItems
        case intentSelect(id: Item.ID?)
        case intentCreate(Item)
        case intentUpdate(Item)
        case intentDelete(Item)
        case intentConfirmError(actionId: ActionID?)
        case intentCancelActivity
        case dismissSheet
        case serviceDidSendItems([Item])
        case serviceDidFailWithError(Swift.Error, action: ActionID)
    }

    struct Env {
        var loadItems: () async throws -> [Item]
        var transducerInput: Input
    }

    enum Output {
        case none
        case itemSelected(id: Item.ID?)
    }
    
    static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
        switch (state, event) {
        case (.start, .start):
            return (initContextEffect(), .none)

        case (.start, .initContext(let context)):
            // TODO: we might want to load items here
            state = .idle(.empty(.blank), context)
            return (nil, .none)

        case (.idle(let content, let context), .intentLoadItems):
            state = .modal(.loading(nil), content, context)
            // TODO: Replace with correct Oak async effect
            let effect: Self.Effect? = nil
            return (effect, .none)

        case (.idle(.data(var data), let context), .intentSelect(let id)):
            assert(data.items.contains(where: { $0.id == id }))
            data.current = id
            state = .idle(.data(data), context)
            return (nil, .itemSelected(id: id))

        case (.modal(.sheet(.create), let content, let context), .intentCreate(let item)):
            state = .modal(.sheet(.create(.init(item: item))), content, context)
            return (nil, .none)

        case (.modal(.sheet(.edit), let content, let context), .intentUpdate(let item)):
            state = .modal(.sheet(.edit(.init(item: item))), content, context)
            return (nil, .none)

        case (.idle(let content, let context), .intentDelete(let item)):
            state = .modal(.sheet(.delete(.init(item: item))), content, context)
            return (nil, .none)

        case (.modal(.loading, _, let context), .serviceDidSendItems(let items)):
            let selected = items.first?.id
            let data: Data = .init(
                items: items, sortOrder: .byCreationDate(.asc), current: selected
            )
            state = .idle(.data(data), context)
            return (nil, .itemSelected(id: selected))

        case (.modal(.loading, let content, let context), .serviceDidFailWithError(let error, let actionId)):
            state = .modal(.error(Error(error, actionId: actionId)), content, context)
            return (nil, .none)

        case (.modal(.loading, let content, let context), .intentCancelActivity):
            state = .idle(content, context)
            return (nil, .none)

        case (.modal(.error(let error), let content, let context), .intentConfirmError(let actionId)):
            // if content is empty, set up the empty view accordingly:
            // TODO: we still need to configure the actions depending on
            // what action has failed. Currently, we have no such info
            // what service/action has failed.
            switch content {
            case .empty:
                // Configure the empty view with the error message
                var actions: [State.Intent] = []
                switch error.actionId {
                case .loadItems:
                    actions = [.init(title: "Retry", action: { try? context.input.send(.intentLoadItems) })]
                default:
                    break
                }
                let emptyData: State.Empty = .filled(
                    title: "Error", 
                    description: error.error.localizedDescription,
                    actions: actions
                )
                state = .idle(.empty(emptyData), context)
            case .data:
                // Data content is not empty, no need to configure
                state = .idle(content, context)
            }
            return (nil, .none)

        case (.modal(.sheet, let content, let context), .dismissSheet):
            state = .idle(content, context)
            return (nil, .none)

        case (.modal, _):
            print("unhandled event \(event) in modal state")
            return (nil, .none)

       case (.idle, _):
           print("unhandled event \(event) in idle state")
           return (nil, .none)

       case (.start, _):
           print("unhandled event \(event) in start state")
           return (nil, .none)
        }
    }

    // MARK: - Effects Implementation

    /// This effect "imports" the context from the environment into the transducer.
    /// The context contains everything the actor knows about that the update function needs.
    static func initContextEffect() -> Self.Effect {
        Effect(isolatedAction: { env, isolated in
            return .initContext(Context(input: env.transducerInput))
        })
    }

    static func serviceLoadItemsEffect() -> Self.Effect {
        Effect(id: ActionID.loadItems, isolatedOperation: { env, input, systemActor in
            do {
                let items = try await env.loadItems()
                try input.send(.serviceDidSendItems(items))
            } catch {
                try input.send(.serviceDidFailWithError(error, action: .loadItems))
            }
        })
    }

}

// MARK: - Detail Transducer
