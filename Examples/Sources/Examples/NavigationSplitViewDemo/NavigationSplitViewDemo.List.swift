// NavigationSplitView.List.swift
//
// Demonstrates using Oak with SwiftUI's NavigationSplitView.

import Foundation
import Oak

// Some thoughts to the implementation

// # Function
//
// 1. When a transducer needs to show a modal, it needs to delegate this
//    task to its actor with using an effect `actorShow(:)` whith the
//    sheet item as parameter.
// 1. The transducer enters a certain state when presenting a modal.
// 2. The tranducer only transitions away from this modal state when it
//    receives a certain event that signals the dismissal of the modal.
// 1. The modal is required to send this dismissal event `modalDidDismiss`.
//    Usually, this event is sent by the view, when the view has been
//    dismissed and transition has ended.
// 1. This dismissal event is the last event the modal will send.
// 1. The modal also should either send a intentCommit or an intentCancel
//    event. If none is sent before the dismissal event, the trasnsducer
//    assumes a cancellation.
// 1. The transducer presenting the modal cannot directly dismiss the modal,
//    but it can send events to it, which the modal can interpret as an
//    intent to dismiss/cancel the modal. That is, just transitioning away
//    from the modal state will not change the presentation state.
//
//    state which represents this modality.
// 1. When a view pesents the Edit, New or Delete modals, it is assumed,
//    that the transducer whose actor is the presenter does only know
//    the API for the modal.

// # State Driven
//
// 1. When a transducer needs to show a modal, it constructs a sheet
//    item value and transitions to a modal state with the sheet item as
//    parameter.
// 1. The transducer assumes the actor will observe the state.
// 1. The actor abserves the state and in case state is modal it extracts
//    the sheet value and presents the sheet with the input parameters
//    given in the sheet item vale.
// 1  The transducer assumes, the modal will not be dismissed, unless it
//    transitions away from the modal state.
// 1. When the transducer is in a modal state, it listens to intentCommit and
//    intentCancel events from the modal. On either of these, the transducer
//    takes actions and then may or may not transition away from the modal.
//    The transducer assumes, that when receiving these events, the modal
//    will NOT itself dismiss
// 1. The presenting transducer will not receive events from modals that
//    have been presented by this modal. These events must be handled by
//    the presenting modal itself.
// 1. The transducer may carry additional state along the sheet item value,
//    when in a modal state. This is required in situations where the modal
//    should stay presented and post processing logic should be applied to the
//    returned value which requires additional state (this may or may not be
//    embedded in the sheet item). The post process logic should be synchronous.
//    Async operations should be avoided. In such cases, it is better to handle
//    the operation in the modal itself in order to keep the logic of the
//    presenting transducer simple.
// 1. The actor observes the state and in case state is not modal it
//    unpresents the modal.
// 1. When a modal will be unpresented it transitions away. When the
//    transition is complete, it should send a modalDidDismiss event to
//    the presenter transducer. Usually, this event is sent by the view,
//    when the view has been dismissed and transition has ended.
// 1. This dismissal event is the last event the modal will send.
// 1. The modal also should either send a intentCommit or an intentCancel
//    event. If none is sent before the dismissal event, the trasnsducer
//    assumes a cancellation.
// 1. When a view pesents the Edit, New or Delete modals, it is assumed,
//    that the transducer whose actor is the presenter does only know
//    the API for the modal.



// MARK: - List List Transducer


extension NavigationSplitViewDemo.List: EffectTransducer {
// MARK: - Model

    // The item model for the main view.
    // 
    // The main view is using a ListView to show an array of items.
    // Note, that an `Item` in the `List` namespace is different 
    // from the `Item` in the `Detail` namespace.
    struct Item: Identifiable, Hashable {
        let id: UUID
        let name: String
        let detail: String
    }

    
    // Sheet Item
    //
    // This enum defines the various sheets that the view for this
    // transducer can present.
    //
    // The item will be available in the presenter, which is usally the
    // transducer's view or a parent view, and in the sheet that will be
    // presented.
    //
    // The transducer sets this sheet item in a "modal" state when the
    // sheet should be presented (executed by the view). When the transducer
    // wants the sheet to be dismissed, it transitions to another non-modal
    // state.
    // The actor (view) of the transducer needs to observe changes in
    // the state so that it can present and dismiss the sheet as requested.
    public enum SheetItem {
        struct Edit: Identifiable {
            public let id = 1
            public typealias Input = Item
            public typealias Output = Item
        
            public var input: Input

            public var cancel: () -> Void
            public var commit: (Output) -> Void
            public var didDismiss: () -> Void

        }
        struct Create: Identifiable {
            public let id = 2
            public typealias Input = String // Title
            public typealias Output = Item

            public var input: Input

            public var cancel: () -> Void
            public var commit: (Output) -> Void
            public var didDismiss: () -> Void
        }
        struct Delete: Identifiable {
            public let id = 3
            public typealias Input = Item.ID
            public typealias Output = Item.ID

            public var input: Input

            public var cancel: () -> Void
            public var commit: (Output) -> Void
            public var didDismiss: () -> Void
        }

        case create(Create)
        case edit(Edit)
        case delete(Delete)
    }
    
    // Non-empty Content of the View
    struct Data {
        enum Sortorder {
            enum Direction { case asc, desc }
            case byCreationDate(Direction)
            case byDueDate(Direction)
        }

        var items: [Item] = []
        var sortOrder: Sortorder = .byCreationDate(.asc)
        var current: Item.ID? = nil  // selected
        
        var currentItem: Item? {
            if let current {
                let item = items.first(where: { $0.id == current })
                return item
            }
            return nil
        }
    }

    struct Error {
        init(_ error: Swift.Error, operationId: Effects.OperationID? = nil) {
            self.error = error
            self.operationId = operationId
        }
        var error: Swift.Error
        var operationId: Effects.OperationID? = nil
    }

    struct Context {
        let input: Input
    }

    typealias State = NavigationSplitViewUtilities.State<Data, SheetItem, Error, Context>
    typealias NewItem = Item
    
    enum Event {
        case start
        case initContext(Context)

        case intentLoadItems
        case intentSelect(id: Item.ID?)
        case intentNewItem // user wants to create a new Item
        case intentEditItem(Item) // user want to edit an existing Item
        case intentDeleteItem(id: Item.ID) // user want to delete an existing Item
        case intentConfirmError(actionId: Effects.OperationID?) // user confirmed an error alert by tapping "OK"

        case serviceDidSendItems([Item])
        case serviceDidFailWithError(Swift.Error, action: Effects.OperationID)
        
        
        case modalDidDismiss // called from the presented view when it dissmissed.
        case modalIntentCancelModal // called when the user did cancel the current modal
        case modalDidCreateItem(Item) // called from the Create modal when it received a success response from the service
        case modalDidUpdateItem(Item) // called from the Edit modal when it received as success response from the service
        case modalDidDeleteItem(id: Item.ID) // called from the Delete modal when it received as success response from the service
    }

    struct Env {
        var serviceLoadItems: () async throws -> [Item]
        var transducerInput: Input
    }

    enum Output {
        case none
        case itemSelected(id: Item.ID?)
    }
    
    static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
        switch (state, event) {
        case (.start, .start):
            return (Effects.initContextEffect(), .none)

        case (.start, .initContext(let context)):
            // TODO: we might want to load items here
            state = .idle(.none(.blank), context: context)
            return (nil, .none)

        case (.idle(let content, let context), .intentLoadItems):
            state = .modal(.activity(), content: content, context: context)
            return (Effects.serviceLoadItems(), .none)

        case (.idle(.some(var data), let context), .intentSelect(let id)):
            assert(data.items.contains(where: { $0.id == id }))
            data.current = id
            state = .idle(.some(data), context: context)
            return (nil, .itemSelected(id: id))

        case (.idle(let content, let context), .intentNewItem):
            // Create a sheet item "Create" with input data and action
            // bindings:
            let input = context.input
            let sheetItem: SheetItem = .create(
                SheetItem.Create(
                    input: "New Todo",
                    cancel: { try? input.send(.modalIntentCancelModal) },
                    commit: { try? input.send(.modalDidCreateItem($0))},
                    didDismiss: { try? input.send(.modalDidDismiss)}
                )
            )
            state = .modal(.sheet(sheetItem), content: content, context: context)
            return (nil, .none)

        case (.idle(let content, let context), .intentEditItem(let item)):
            // Create a sheet item "Edit" with input data and action
            // bindings:
            let input = context.input
            let sheetItem: SheetItem = .edit(
                SheetItem.Edit(
                    input: item,
                    cancel: { try? input.send(.modalIntentCancelModal) },
                    commit: { try? input.send(.modalDidUpdateItem($0))},
                    didDismiss: { try? input.send(.modalDidDismiss)}
                )
            )
            state = .modal(.sheet(sheetItem), content: content, context: context)
            return (nil, .none)

        case (.idle(let content, let context), .intentDeleteItem(let id)):
            // Create a sheet item "Delete" with input data and action
            // bindings:
            let input = context.input
            let sheetItem: SheetItem = .delete(
                SheetItem.Delete(
                    input: id,
                    cancel: { try? input.send(.modalIntentCancelModal) },
                    commit: { try? input.send(.modalDidDeleteItem(id: $0))},
                    didDismiss: { try? input.send(.modalDidDismiss)}
                )
            )
            state = .modal(.sheet(sheetItem), content: content, context: context)
            return (nil, .none)

        case (.modal(.sheet(.create), _, _), .modalDidCreateItem(let item)):
            // Dismiss the modal, and reload the items in order to update the
            // list. We need to ensure that we do not load stale data from
            // caches, such as an HTTP cache.
            // As an improvement of the UX, we pre-insert `item` into the local
            // list and set the selection to the new item:
            state.update(with: item)
            return (Effects.serviceLoadItems(), .none)

        case (.modal(.sheet(.edit), _, _), .modalDidUpdateItem(let item)):
            // Dismiss the modal, and reload the items in order to update the
            // list. We need to ensure that we do not load stale data from
            // caches, such as an HTTP cache.
            state.update(with: item)
            return (Effects.serviceLoadItems(), .none)

        case (.modal(.sheet(.delete), _, _), .modalDidDeleteItem(let id)):
            // Dismiss the modal, and reload the items in order to update the
            // list. We need to ensure that we do not load stale data from
            // caches, such as an HTTP cache.
            state.removeItem(with: id)
            return (Effects.serviceLoadItems(), .none)

        case (.modal(.activity, _, _), .serviceDidSendItems(let items)):
            state.updateItems(items)
            return (nil, .itemSelected(id: state.selectedItemId))

        case (.modal(.activity, let content, let context), .serviceDidFailWithError(let error, let actionId)):
            state = .modal(.error(Error(error, operationId: actionId)), content: content, context: context)
            return (nil, .none)

        case (.modal(.activity, let content, let context), .modalIntentCancelModal):
            state = .idle(content, context: context)
            return (nil, .none)

        case (.modal(.error(let error), _, let context), .intentConfirmError(let actionId)):
            state.updateOnConfirmError(error, actionId: actionId, with: context)
            return (nil, .none)

        case (.modal(.sheet, let content, let context), .modalDidDismiss):
            state = .idle(content, context: context)
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
}

    // MARK: - List Effects Implementation
extension NavigationSplitViewDemo.List.Effects {

    // This is an id for a certain kind of action/operation
    // that will be executed as an effect, and which may fail
    // and return an error. The ID will be used to identify
    // the managed task and may also help the transducer to
    // identify which kind of action it was that caused the
    // error (but not which instance of this action it was).
    enum OperationID: Equatable, Identifiable, Hashable {
        case loadItems
        
        var id: Self { self }
    }

    typealias Effect = NavigationSplitViewDemo.List.Effect
    typealias Context = NavigationSplitViewDemo.List.Context


    /// This effect "imports" the context from the environment into the transducer.
    /// The context contains everything the actor knows about that the update function needs.
    static func initContextEffect() -> Effect {
        Effect { env, isolated in
            .initContext(Context(input: env.transducerInput))
        }
    }

    static func serviceLoadItems() -> Effect {
        Effect(id: OperationID.loadItems, isolatedOperation: { env, input, systemActor in
            do {
                let items = try await env.serviceLoadItems()
                try input.send(.serviceDidSendItems(items))
            } catch {
                try input.send(.serviceDidFailWithError(error, action: .loadItems))
            }
        })
    }

}

// MARK: - Detail Transducer
#if false
extension NavigationSplitViewDemo.Detail: EffectTransducer {

    struct Context {        
        let input: Input
    }

    struct Env {
        var loadItem: (Item.ID) async throws -> Item  
        var transducerInput: Input
    }

    struct Data {
        var item: Item
    }

    typealias Item = NavigationSplitViewDemo.Item

    enum Event {
        case start
        case initContext(Context)
        case intentEdit(id: Item.ID)
        case intentNew
        case intentDelete(Item.ID)
        case serviceDidUpdateItem(Item)
        case serviceDidFailWithError(Swift.Error)
    }

    typealias State = NavigationSplitViewUtilities.State<Data, Sheet, Error, Context>

    static func updateState(_ state: inout State, with event: Event) {
        switch (state,event) {
        }
    }   
}
#endif


// MARK: State Mutation Helpers
extension NavigationSplitViewDemo.List.State {
    
    typealias ActionID = NavigationSplitViewDemo.List.Effects.OperationID
    typealias Item = NavigationSplitViewDemo.List.Item

    mutating func updateItems(_ items: [Item]) {
        var newData: Self.Data
        switch content {
        case .some(let data) where !items.isEmpty:
            newData = data
            newData.items = items
            if let currentId = newData.current, newData.items.first(where: { $0.id == currentId }) != nil {
                // keep selection
            } else {
                newData.current = items.first?.id
            }
            self.content = .some(newData)
            self.sortItems()
        case .none where !items.isEmpty:
            newData = .init(
                items: items,
                sortOrder: .byCreationDate(.asc),
                current: items.first?.id
            )
            self.content = .some(newData)
            self.sortItems()

        default:
            self.content = .none()
        }
    }

    mutating func update(with item: Item) {
        var newData: Self.Data
        switch content {
        case .some(let data):
            newData = data
            newData.items.append(item)
            newData.current = item.id
            self.content = .some(newData)
            self.sortItems()
        case .none:
            newData = .init(
                items: [item],
                sortOrder: .byCreationDate(.asc),
                current: item.id
            )
        }
    }
    
    @discardableResult
    mutating func removeItem(with id: Item.ID) -> Bool {
        switch content {
        case .some(let data):
            var newData = data
            if let firstIndex = newData.items.firstIndex(where: { $0.id == id }) {
                newData.items.remove(at: firstIndex)
            } else {
                return false
            }
            switch newData.items.count {
            case 0:
                content = .none(.filled(title: "No items", description: "", actions: []))
            default:
                content = .some(newData)
            }
            self.content = .some(newData)
            return true
        case .none:
            return false
        }
    }
    
    mutating func sortItems() {
        switch content {
        case .none: return
        case .some(var data):
            // TODO: implement sort using the sort spec
            data.items.sort(by: { lhs, rhs in
                lhs.name > rhs.name
            })
            self.content = .some(data)
        }
    }
    
    var selectedItemId: Item.ID? {
        switch content {
        case .none: return nil
        case .some(let data):
            return data.current
        }
    }
    
    mutating func updateOnConfirmError(_ error: Self.Error, actionId: ActionID?, with context: Context) {
        // if content is empty, set up the empty view accordingly:
        // TODO: we still need to configure the actions depending on
        // what action has failed. Currently, we have no such info
        // what service/action has failed.
        switch content {
        case .none:
            // Configure the empty view with the error message
            var actions: [Intent] = []
            switch actionId {
            case .loadItems:
                actions = [.init(title: "Retry", action: { try? context.input.send(.intentLoadItems) })]
            default:
                break
            }
            let emptyData: Empty = .filled(
                title: "Error",
                description: error.error.localizedDescription,
                actions: actions
            )
            self = .idle(.none(emptyData), context: context)
        case .some:
            // Data content is not empty, no need to configure
            self = .idle(content, context: context)
        }
    }
}

extension Array where Element: Identifiable {
    subscript (id: Element.ID) -> Element? {
        get {
            self.first { $0.id == id }
        }
        set {
            guard let newValue else { return }
            if let firstIndex = self.firstIndex(where: { $0.id == id }) {
                self[firstIndex] = newValue
            } else {
                self.append(newValue)
            }
        }
    }
}
