import SwiftUI
import UIKit

/// Представление элемента комбинированной еды
struct CombinedFoodItemView: View {
    let combinedFood: CombinedFoodItem
    let offset: CGFloat
    let onDelete: () -> Void
    let onTap: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void
    let getFormattedTime: (Date) -> String
    
    // Состояние для отслеживания, был ли свайп
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Кнопка удаления (справа)
            HStack {
                Spacer()
                Button(action: {
                    // Добавляем вибрацию при нажатии на кнопку удаления
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .frame(width: 60, height: 80)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                .opacity(offset < -5 ? 1 : 0) // Показываем кнопку только при свайпе
            }
        
            // Основная карточка еды
            VStack {
                HStack(spacing: 20) {
                    // Изображение блюда
                    CombinedFoodImageView(combinedFood: combinedFood)
                    
                    // Информация о блюде
                    CombinedFoodNutritionView(combinedFood: combinedFood)
                    
                    Spacer()
                    
                    // Время добавления
                    Text(getFormattedTime(combinedFood.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                )
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            isDragging = true
                            onDragChanged(gesture.translation.width)
                        }
                        .onEnded { gesture in
                            onDragEnded(gesture.translation.width)
                            
                            // Убрана тактильная вибрация при свайпе
                            
                            // Reset dragging state after animation completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isDragging = false
                            }
                        }
                )
                // Отдельный gesture для обработки нажатия
                .onTapGesture {
                    if !isDragging {
                        onTap()
                    }
                }
            }
        }
    }
}

/// Представление деталей комбинированного блюда
private struct CombinedFoodNutritionView: View {
    let combinedFood: CombinedFoodItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Используем только английское название
            Text(combinedFood.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.primary)
            
            HStack {
                // Calories remain with flame icon but in square format
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    )
                Text("\(Int(combinedFood.calories)) calories")
                    .font(.subheadline)
                    .foregroundColor(Color.primary.opacity(0.8))
            }
            
            // Nutrient icons with values
            HStack(spacing: 12) {
                // Proteins - P in red square
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("P")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(Int(combinedFood.protein))g")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
                
                // Carbs - C in blue square
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("C")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(Int(combinedFood.carbs))g")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
                
                // Fats - F in orange square
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("F")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(Int(combinedFood.fat))g")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
        }
    }
}

/// View для отображения изображения комбинированного блюда
private struct CombinedFoodImageView: View {
    let combinedFood: CombinedFoodItem
    
    var body: some View {
        ZStack {
            if let imageData = combinedFood.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    // Removed ingredient count overlay
            } else {
                // Fallback with first ingredient image if available
                if let firstIngredient = combinedFood.ingredients.first,
                   let imageData = firstIngredient.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        // Removed ingredient count overlay
                } else {
                    // Default icon
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                        
                        Image(systemName: "fork.knife")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                    // Removed ingredient count overlay
                }
            }
        }
    }
}





