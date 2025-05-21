import SwiftUI
import Vision

struct LabelScannerView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    var onComplete: (FoodNutrition?) -> Void
    var onClose: () -> Void
    
    @State private var isAnalyzing = true
    @State private var recognizedText = ""
    @State private var nutritionInfo: FoodNutrition?
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Фон
            Color.black.opacity(0.9).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Отображение изображения
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .cornerRadius(12)
                    .padding()
                
                // Область для отображения информации о распознавании
                if isAnalyzing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Анализируем информацию о питательной ценности...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if let nutrition = nutritionInfo {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Распознанная информация:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            NutritionInfoRow(name: "Калории", value: "\(Int(nutrition.calories)) ккал")
                            NutritionInfoRow(name: "Белки", value: "\(nutrition.protein) г")
                            NutritionInfoRow(name: "Жиры", value: "\(nutrition.fat) г")
                            NutritionInfoRow(name: "Углеводы", value: "\(nutrition.carbs) г")
                            
                            if let sugars = nutrition.sugars {
                                NutritionInfoRow(name: "Сахара", value: "\(sugars) г")
                            }
                            
                            if let fiber = nutrition.fiber {
                                NutritionInfoRow(name: "Клетчатка", value: "\(fiber) г")
                            }
                            
                            NutritionInfoRow(name: "Размер порции", value: "\(nutrition.servingSize) \(nutrition.servingUnit)")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                // Кнопки
                HStack(spacing: 20) {
                    Button(action: {
                        onClose()
                    }) {
                        Text("Отмена")
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    if let nutrition = nutritionInfo {
                        Button(action: {
                            onComplete(nutrition)
                        }) {
                            Text("Сохранить")
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.vertical)
            }
            .padding()
        }
        .onAppear {
            // Начинаем анализ изображения
            recognizeText()
        }
    }
    
    private func recognizeText() {
        // Симулируем задержку для анализа
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isAnalyzing = false
            
            // Для демонстрации создаем фиктивный объект питательной информации
            nutritionInfo = FoodNutrition(
                calories: 52,
                protein: 0.3,
                carbs: 14.0,
                fat: 0.2,
                sugars: 10.0,
                fiber: 2.4,
                sodium: 1.0,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Apple",
                source: "scanned"
            )
            
            // Код для реального распознавания текста с помощью Vision API будет здесь
            // Но для простоты демонстрации мы используем фиктивные данные
        }
    }
}

struct NutritionInfoRow: View {
    let name: String
    let value: String
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

struct LabelScannerView_Previews: PreviewProvider {
    static var previews: some View {
        LabelScannerView(
            image: UIImage(systemName: "photo")!,
            isPresented: .constant(true),
            onComplete: { _ in },
            onClose: {}
        )
    }
}

