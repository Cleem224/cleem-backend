import SwiftUI

struct AddButton: View {
    @State private var showQuickActions = false
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        Button(action: {
            self.showQuickActions.toggle()
        }) {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.green)
                .shadow(radius: 4)
        }
        .sheet(isPresented: $showQuickActions, onDismiss: {
            // Handle dismissal if needed
        }) {
            QuickActionsView()
                .environmentObject(navigationCoordinator)
        }
    }
} 