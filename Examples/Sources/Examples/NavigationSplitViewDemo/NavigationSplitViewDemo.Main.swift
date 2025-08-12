import SwiftUI
import Oak

extension NavigationSplitViewDemo.Main.Views {
    
    struct ToDo: Identifiable, Equatable {
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
    
    
    struct ContentNavigationView: View {
        var body: some View {
            NavigationStack {
                MainDetailView()
            }
        }
    }
    
    typealias DetailProxy = Proxy<String>
    typealias MainProxy = Proxy<String>

    struct MainDetailView: View {
        
        typealias DetailCallback = Callback<String>
        
        @State private var detailProxy: DetailProxy?
        @State private var mainProxy: MainProxy?
        

        var body: some View {
            NavigationSplitView {
                
                List(model.employees, selection: $employeeIds) { employee in
                    Text(employee.name)
                }
            } detail: {
                EmployeeDetails(for: employeeIds)
            }
        }
        
        func wireup(mainProxy: MainProxy, detailProxy: DetailProxy) {
            
        }
    }
    
    
    struct DetailView: View {
        let proxy: DetailProxy
        
        var body: some View {
            
        }
    }
    
}
