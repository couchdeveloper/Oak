//
//  Subject.SwftUI.swift
//  Oak
//
//  Created by Andreas Grosam on 10.05.25.
//

import SwiftUI

extension Binding: Oak.Subject {
    public func send(_ value: Value) async throws {
        self.wrappedValue = value
    }
}

#if false
extension Binding where Value: Sendable {
    public var asOakSubject: some Oak.Subject {
        BindingSubject(self)
    }
}
struct BindingSubject<Value: Sendable>: Oak.Subject, Sendable {
    let binding: Binding<Value>
    
    init(_ binding: Binding<Value>) {
        self.binding = binding
    }
    
    func send(_ value: Value) async throws {
        binding.wrappedValue = value
    }
}
#endif
