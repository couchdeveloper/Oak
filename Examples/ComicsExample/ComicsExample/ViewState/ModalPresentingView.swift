#if false


import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

extension Modality {
    func binding<Value>(
        for keyPath: KeyPath<Self, Value>, dismiss: @escaping () -> Void
    ) -> Binding<Value> {
        Binding<Value>(
            get: { self[keyPath: keyPath] },
            set: { _ in dismiss() }
        )
    }
}

extension SwiftUI.ProgressView where CurrentValueLabel == EmptyView {
    init(_ progressState: ProgressState) where Label == Text {
        self.init(label: {
            Label(progressState.label)
                .font(.subheadline)
        } )
    }
}

extension SwiftUI.Alert  {
    init(_ alertState: AlertState) {
        self.init(title: Text(alertState.title),
                      message: Text(alertState.message))
    }
}

#if canImport(UIKit)
extension SwiftUI.ActionSheet  {
    init(_ actionSheetState: ActionSheetState) {
        self.init(title: Text(actionSheetState.title))
    }
}
#endif


public extension View {
    typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>

    @ViewBuilder
    func modal(_ modal: Modal?, dismiss: @escaping () -> Void) -> some View {
        if let modal = modal {
            self
                .progress(item: modal.binding(for: \.progress, dismiss: dismiss)) { progress in
                    ZStack {
                        //Color(UIColor.quaternarySystemFill).edgesIgnoringSafeArea(.all)
                        ProgressView(progress)//.scaleEffect(2.0, anchor: .center)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.black))
                        .padding(16)
                        .background(Color.gray.opacity(0.95))
                        .foregroundColor(Color.black)
                        .cornerRadius(8)
                    }
            }
            .alert(item: modal.binding(for: \.alert, dismiss: dismiss)) { alert in
                SwiftUI.Alert(alert)
            }
            .sheet(item: modal.binding(for: \.sheet, dismiss: dismiss)) { sheet in
                Color.red
            }
#if canImport(UIKit)
            .actionSheet(item: modal.binding(for: \.actionSheet, dismiss: dismiss)) { actionSheet in
                SwiftUI.ActionSheet(actionSheet)
            }
#endif

        } else {
            self
        }
    }
}


extension View {
    @ViewBuilder
    func progress<T, Content>(item: Binding<T?>, content: (T) -> Content) -> some View where Content: View {
        if let value = item.wrappedValue {
            ZStack {
                self
                #if canImport(UIKit)
                Color(UIColor.quaternarySystemFill)
                    .ignoresSafeArea()
                #elseif canImport(AppKit)
                Color(NSColor.quaternaryLabelColor)
                    .ignoresSafeArea()
                #else
                Color.gray.opacity(0.2)
                    .ignoresSafeArea()
                #endif
                //.blur(radius: 16)
                content(value)
            }
        } else {
            self
        }
    }
}


#if DEBUG

// MARK: - Preview

struct ModalPresentingView_Previews: PreviewProvider {

    struct HappyView: View {
        let state: String

        var body: some View {
            VStack {
                Text(verbatim: state)
                    .background(Color.blue)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    static var previews: some View {
        Group {
            HappyView(state: "Happy View")
            .modal(nil, dismiss: {})

            HappyView(state: "Happy View with Alert")
                .modal(
                    .alert(
                        AlertState(
                            title: "Alert",
                            message: "Alert message"
                        )
                    ),
                    dismiss: {}
                )


            HappyView(state: "Happy View with loading")
                .modal(
                    .progress(ProgressState(label: "loading…")),
                    dismiss: {}
                )

            HappyView(state: "Happy View with loading")
                .modal(
                    .progress(ProgressState(label: "loading…")),
                    dismiss: {}
                )
                .preferredColorScheme(.dark)
        }
    }
}


//protocol ViewModelObserving {
//    associatedtype ViewModel: MVVM.ViewModel
//    var viewModel: ViewModel { get }
//}
//
//extension ViewModelObserving {
//    func binding<Value>(
//        for keyPath: KeyPath<ViewModel.State, Value>,
//        transform: @escaping (Value) -> ViewModel.Event
//    ) -> Binding<Value> {
//        Binding<Value>(
//            get: { self.viewModel.state[keyPath: keyPath] },
//            set: { self.viewModel.send(transform($0)) }
//        )
//    }
//}


#endif
#endif
