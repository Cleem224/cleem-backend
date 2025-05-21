import SwiftUI

struct WeightSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedWeight: Int = 70 // Default weight in kg
    @State private var selectedUnit: WeightUnit = .kg
    @State private var animateContent = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    enum WeightUnit: String, CaseIterable, Identifiable {
        case kg, lbs
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            // Фон экрана - светло-голубой
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer().frame(height: 80)
                
                // Заголовок и подзаголовок - перемещены в центр экрана
                VStack(spacing: 16) {
                    Text("Your Weight")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    
                    Text("Please select your current weight")
                        .font(.system(size: 18))
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                }
                
                Spacer().frame(height: 40)
                
                // Выбор единицы измерения
                Picker("Units", selection: $selectedUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.rawValue.uppercased())
                            .tag(unit)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .background(Color.white.opacity(0.7))
                .cornerRadius(10)
                .padding(.horizontal, 50)
                .padding(.bottom, 30)
                .onChange(of: selectedUnit) { _, newValue in
                    if newValue == .lbs {
                        // Конвертировать из кг в фунты
                        selectedWeight = kgToLbs(selectedWeight)
                    } else {
                        // Конвертировать из фунтов в кг
                        selectedWeight = lbsToKg(selectedWeight)
                    }
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                
                // Визуальное отображение веса
                VStack(spacing: 16) {
                    ZStack {
                        // Весы
                        Image(systemName: "scalemass.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .padding(.bottom, 20)
                    
                    Text(weightString)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                
                // Слайдер выбора веса
                VStack {
                    Slider(value: Binding(
                        get: { Double(selectedWeight) },
                        set: { selectedWeight = Int($0) }
                    ), in: selectedUnit == .kg ? 40...150 : 88...330)
                    .tint(.black)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Отображение диапазона
                    HStack {
                        Text(selectedUnit == .kg ? "40 kg" : "88 lbs")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(selectedUnit == .kg ? "150 kg" : "330 lbs")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 30)
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                
                Spacer()
                
                // Continue button
                Button {
                    // Сохраняем вес в профиле пользователя
                    if selectedUnit == .kg {
                        navigationCoordinator.userProfile.weightInKg = Double(selectedWeight)
                    } else {
                        navigationCoordinator.userProfile.weightInKg = Double(lbsToKg(selectedWeight))
                    }
                    
                    withAnimation {
                        DispatchQueue.main.async {
                            onContinue()
                        }
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 40)
            }
            
            // Кнопка "Назад" и индикатор прогресса в верхней части
            VStack {
                HStack {
                    Button(action: onBack) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                            
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .padding(.leading, 20)
                    
                    // Индикатор прогресса
                    ProgressBarView(currentStep: 4, totalSteps: 8)
                        .padding(.leading, 10)
                        .padding(.trailing, 20)
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .onAppear {
            // Инициализируем вес из профиля пользователя, если есть
            if navigationCoordinator.userProfile.weightInKg > 0 {
                if selectedUnit == .kg {
                    selectedWeight = Int(navigationCoordinator.userProfile.weightInKg)
                } else {
                    selectedWeight = kgToLbs(Int(navigationCoordinator.userProfile.weightInKg))
                }
            }
            
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
    
    // Строковое представление веса
    private var weightString: String {
        if selectedUnit == .kg {
            return "\(selectedWeight) kg"
        } else {
            return "\(selectedWeight) lbs"
        }
    }
    
    // Конвертация из кг в фунты
    private func kgToLbs(_ kg: Int) -> Int {
        return Int(Double(kg) * 2.2046)
    }
    
    // Конвертация из фунтов в кг
    private func lbsToKg(_ lbs: Int) -> Int {
        return Int(Double(lbs) / 2.2046)
    }
}

struct WeightSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        WeightSelectionView(onContinue: {}, onBack: {})
            .environmentObject(NavigationCoordinator.shared)
    }
} 