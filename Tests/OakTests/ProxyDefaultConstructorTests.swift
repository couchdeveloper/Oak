import Testing
import Oak
import Foundation

@MainActor
struct ProxyDefaultConstructorTests {
    
    @Test
    func proxyHasDefaultConstructor() {
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test }
            
            static func update(_ state: inout State, event: Event) {}
        }
        
        // Test that Proxy can be created with default constructor
        let proxy = TestTransducer.Proxy()
        #expect(proxy.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
    
    @Test
    func syncSuspendingProxyHasDefaultConstructor() {
        // Test that SyncSuspendingProxy also has default constructor
        let syncSuspendingProxy = Oak.SyncSuspendingProxy<String>()
        #expect(syncSuspendingProxy.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
    
    @Test
    func defaultProxyCanSendEvents() throws {
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test }
            
            static func update(_ state: inout State, event: Event) {}
        }
        
        let proxy = TestTransducer.Proxy()
        
        // Verify that the default-constructed proxy can send events
        #expect(throws: Never.self) {
            try proxy.send(.test)
        }
    }
    
    @Test 
    func syncSuspendingProxyConstructorDoesNotHang() async throws {
        // Just test that we can construct the sync suspending proxy without hanging
        let syncSuspendingProxy = Oak.SyncSuspendingProxy<String>()
        
        // Test that the proxy has a valid ID (non-nil UUID)
        #expect(syncSuspendingProxy.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        
        // The test passes if we reach here without hanging on construction
        #expect(true)
    }
}
