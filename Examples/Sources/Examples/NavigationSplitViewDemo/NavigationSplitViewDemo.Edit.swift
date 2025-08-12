// NavigationSplitView.Edit.swift
// Edit modal transducer for Oak NavigationSplitView

import Foundation
import Oak

extension NavigationSplitViewDemo {
    enum Edit {
        enum Effects {}
    }
}

extension NavigationSplitViewDemo.Edit: EffectTransducer {

    struct NoChangesMadeError: LocalizedError {
        var errorDescription: String? {
            return "No changes detected"
        }
        var recoverySuggestion: String? {
            return "Please make changes before saving."
        }
    }
    
    struct Item: Identifiable, Hashable, Equatable {
        enum Status {
            case open
            case closed
        }
        let id: UUID
        var name: String
        var creationDate: Date
        var dueDate: Date
        var detail: String
    }

    enum Event {
        case start(item: Item)
        case intentCommit(Item) // user tapped "commit"
        case intentCancel // user tapped "cancel"
        case intentConfirmError // user tapped an "OK" button in an alert
        case serviceDidUpdateItem(Item) // service responded with success
        case serviceDidFailWithError(Swift.Error) // service responded with error
        case modalDidDismiss // sent from sheet when it has been dismissed
    }

    struct Env {
        var serviceUpdateItem: (Item) async throws -> Item
    }
    
    struct Error {
        init(_ error: Swift.Error) {
            self.error = error
        }
        var error: Swift.Error
    }

    enum State: Terminable {
        case start
        case idle(item: Item)
        case modal(Modal, item: Item)
        case cancelled(item: Item)

        var isTerminal: Bool {
            switch self {
            case .cancelled:
                return true
            default:
                return false
            }
        }

        struct Activity {
            var title: String
        }
        enum Modal {
            case error(Error)
            case activity(Activity)
        }

        var item: Item? {
            switch self {
            case .idle(let item), .modal(_, let item), .cancelled(let item):
                return item
            case .start:
                return nil
            }
        }
        var activity: Activity? {
            switch self {
            case .start, .idle,.cancelled:
                return nil
            case .modal(.activity(let activity), _):
                return activity
            case .modal(.error(_), item: _):
                return nil
            }
        }
        var error: Error? {
            if case .modal(.error(let error), item: _) = self {
                return error
            }
            return nil
        }
    }

    // The output *indirectly* connects to the main transducer.
    // The modal receives a Sheet Item value which already has action
    // bindings to the main transducer setup by the main transducer.
    // The actor (view) in this transducer needs to bind the output
    // closures to these actions. That is, the Edit modal does not
    // know anything about its transducer. It only knows about the
    // Sheet Items.
    enum Output {
        case none
        case didUpdateItem(Item) // should call `commit` of the Sheet.Edit value
        case intentCancelModal // should call `cancel` of the Sheet.Edit value
        case didDismissModal // should call `didDismiss` from a copy of the Sheet.Edit value
    }

    static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
        switch (state, event) {
        case (.start, .start(let item)):
            state = .idle(item: item)
            return (nil, .none)
            
        case (.idle(let item), .intentCommit(let newItem)):
            if item != newItem {
                state = .modal(.activity(.init(title: "Updating...")), item: item)
                return (Effects.serviceUpdateItem(newItem), .none)
            } else {
                state = .modal(.error(Error(NoChangesMadeError())), item: item)
                return (nil, .none)
            }
        case (.idle(let item), .intentCancel):
            state = .cancelled(item: item)
            return (nil, .intentCancelModal)
            
        case (.modal(.activity, _), .serviceDidUpdateItem(let item)):
            state = .idle(item: item)
            return (nil, .didUpdateItem(item))
            
        case (.modal(.activity, let item), .serviceDidFailWithError(let error)):
            state = .modal(.error(Error(error)), item: item)
            return (nil, .none)
            
        case (.modal(.error, let item), .intentConfirmError):
            state = .idle(item: item)
            return (nil, .none)

        case (_, .modalDidDismiss):
            return (nil, .intentCancelModal)

        case (_, _):
            return (nil, .none)
        }
    }
}

extension NavigationSplitViewDemo.Edit.Effects {
    typealias Effect = NavigationSplitViewDemo.Edit.Effect
    typealias Item = NavigationSplitViewDemo.Edit.Item

    static func serviceUpdateItem(_ item: Item) -> Self.Effect {
        Effect(id: "update", isolatedOperation: { env, input, systemActor in
            do {
                let updated = try await env.serviceUpdateItem(item)
                try input.send(.serviceDidUpdateItem(updated))
            } catch {
                try input.send(.serviceDidFailWithError(error))
            }
        })
    }
}
