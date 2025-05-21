import SwiftUI

struct HelpOverlayView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Полупрозрачный фон
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Заголовок
                Text("Помощь по сканированию")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        // Секции справки
                        HelpSection(
                            icon: "camera.viewfinder",
                            title: "Сканирование продуктов",
                            description: "Наведите камеру на продукт так, чтобы он попал в рамку. Держите камеру стабильно и убедитесь, что освещение достаточное."
                        )
                        
                        HelpSection(
                            icon: "barcode.viewfinder",
                            title: "Сканирование штрих-кода",
                            description: "Переключитесь в режим сканирования штрих-кода и наведите камеру на штрих-код продукта. Держите камеру на расстоянии 10-15 см от штрих-кода."
                        )
                        
                        HelpSection(
                            icon: "doc.text.viewfinder",
                            title: "Сканирование этикетки",
                            description: "Для сканирования этикетки с информацией о питательной ценности наведите камеру на этикетку, следя за тем, чтобы весь текст был чётко виден."
                        )
                        
                        HelpSection(
                            icon: "photo",
                            title: "Выбор из галереи",
                            description: "Вы также можете выбрать фото продукта из галереи, нажав на соответствующую кнопку внизу экрана."
                        )
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                
                // Кнопка закрытия
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Text("Закрыть")
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            .padding()
            .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
        }
        .transition(.opacity)
    }
}

// Компонент для отображения секции справки
struct HelpSection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct HelpOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        HelpOverlayView(isPresented: .constant(true))
    }
} 