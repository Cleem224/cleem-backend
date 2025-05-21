import SwiftUI

struct QuickActionsGrid: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                GridActionButton(
                    icon: "figure.walk",
                    title: "Log exercise",
                    action: {}
                )
                
                GridActionButton(
                    icon: "bookmark.fill",
                    title: "Saved foods",
                    action: {}
                )
            }
            
            HStack(spacing: 10) {
                GridActionButton(
                    icon: "magnifyingglass",
                    title: "Food Database",
                    action: {}
                )
                
                GridActionButton(
                    icon: "camera.viewfinder",
                    title: "Scan food",
                    action: {}
                )
            }
        }
    }
}

struct GridActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 25))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.blue)
                    .cornerRadius(15)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

struct QuickActionsGrid_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsGrid()
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color(.systemGray6))
    }
}
