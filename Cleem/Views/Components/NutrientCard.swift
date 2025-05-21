import SwiftUI

struct NutrientCard: View {
    var value: String
    var label: String
    var icon: String
    var color: Color
    var progress: Double
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(value)
                    .font(.system(size: 60, weight: .bold))
                
                Text(label)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading)
            
            Spacer()
            
            LargeCircularProgressView(progress: progress, color: color, icon: icon)
                .frame(width: 120, height: 120)
                .padding(.trailing)
        }
        .frame(height: 150)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

struct MacroCard: View {
    var value: String
    var label: String
    var iconName: String
    var color: Color
    var progress: Double
    
    var body: some View {
        VStack(spacing: 10) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            CircularProgressView(progress: progress, color: color, icon: iconName)
                .frame(width: 80, height: 80)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }
}

struct NutrientCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NutrientCard(
                value: "1712",
                label: "Calories left",
                icon: "flame",
                color: .orange,
                progress: 0.2
            )
            
            HStack(spacing: 10) {
                MacroCard(
                    value: "108g",
                    label: "Protein left",
                    iconName: "drop.fill",
                    color: .red,
                    progress: 0.6
                )
                
                MacroCard(
                    value: "212g",
                    label: "Carbs left",
                    iconName: "leaf.fill",
                    color: .orange,
                    progress: 0.3
                )
                
                MacroCard(
                    value: "47g",
                    label: "Fat left",
                    iconName: "drop.fill",
                    color: .blue,
                    progress: 0.8
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}
