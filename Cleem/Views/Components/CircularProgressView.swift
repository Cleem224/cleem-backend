import SwiftUI

struct CircularProgressView: View {
    var progress: Double
    var color: Color
    var icon: String
    var lineWidth: CGFloat = 10
    
    var body: some View {
        ZStack {
            // Фоновый круг
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Прогресс
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
            
            // Иконка в центре
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
        }
    }
}

// Более крупная версия для отображения калорий
struct LargeCircularProgressView: View {
    var progress: Double
    var color: Color
    var icon: String
    var lineWidth: CGFloat = 15
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
            
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.primary)
        }
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CircularProgressView(progress: 0.7, color: .blue, icon: "drop.fill")
                .frame(width: 80, height: 80)
            
            LargeCircularProgressView(progress: 0.3, color: .orange, icon: "flame")
                .frame(width: 150, height: 150)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
