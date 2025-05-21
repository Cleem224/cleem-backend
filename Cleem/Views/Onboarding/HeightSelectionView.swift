import SwiftUI

struct HeightSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedHeight: Int = 175 // Default height in cm
    @State private var selectedUnit: HeightUnit = .cm
    @State private var animateContent = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    enum HeightUnit: String, CaseIterable, Identifiable {
        case cm, feet
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
                    Text("Your Height")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    
                    Text("Please select your height")
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
                    ForEach(HeightUnit.allCases) { unit in
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
                    if newValue == .feet {
                        // Конвертировать из см в футы
                        selectedHeight = max(cmToFeet(selectedHeight), 4)
                    } else {
                        // Конвертировать из футов в см
                        selectedHeight = min(feetToCm(selectedHeight), 220)
                    }
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                
                // Визуальное отображение роста
                VStack(spacing: 16) {
                    ZStack {
                        // Человечек с индикатором высоты
                        Image(systemName: "person.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
                            .foregroundColor(.black.opacity(0.7))
                        
                        // Горизонтальная линия, показывающая текущую высоту
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 40, height: 2)
                            .offset(x: 50, y: 0)
                    }
                    .padding(.bottom, 20)
                    
                    Text(heightString)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                
                // Слайдер выбора роста
                VStack {
                    Slider(value: Binding(
                        get: { Double(selectedHeight) },
                        set: { selectedHeight = Int($0) }
                    ), in: selectedUnit == .cm ? 140...220 : 4...7)
                    .tint(.black)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Отображение диапазона
                    HStack {
                        Text(selectedUnit == .cm ? "140 cm" : "4 ft")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(selectedUnit == .cm ? "220 cm" : "7 ft")
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
                    // Сохраняем рост в профиле пользователя
                    if selectedUnit == .cm {
                        navigationCoordinator.userProfile.heightInCm = selectedHeight
                    } else {
                        navigationCoordinator.userProfile.heightInCm = feetToCm(selectedHeight)
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
                    ProgressBarView(currentStep: 3, totalSteps: 8)
                        .padding(.leading, 10)
                        .padding(.trailing, 20)
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .onAppear {
            // Инициализируем рост из профиля пользователя, если есть
            if navigationCoordinator.userProfile.heightInCm > 0 {
                if selectedUnit == .cm {
                    selectedHeight = navigationCoordinator.userProfile.heightInCm
                } else {
                    selectedHeight = cmToFeet(navigationCoordinator.userProfile.heightInCm)
                }
            }
            
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
    
    // Строковое представление роста
    private var heightString: String {
        if selectedUnit == .cm {
            return "\(selectedHeight) cm"
        } else {
            let feet = selectedHeight
            let inches = Int((Double(selectedHeight) - Double(feet)) * 12)
            return "\(feet) ft \(inches) in"
        }
    }
    
    // Конвертация из см в футы
    private func cmToFeet(_ cm: Int) -> Int {
        let feet = Double(cm) / 30.48
        return Int(feet)
    }
    
    // Конвертация из футов в см
    private func feetToCm(_ feet: Int) -> Int {
        return Int(Double(feet) * 30.48)
    }
}

struct HeightSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        HeightSelectionView(onContinue: {}, onBack: {})
            .environmentObject(NavigationCoordinator.shared)
    }
} 