import SwiftUI
import CoreHaptics

// MARK: - Weight Ruler Picker View
struct WeightRulerPickerView: View {
    // MARK: - Properties
    @Binding var selectedWeight: Double
    let minWeight: Double
    let maxWeight: Double
    let step: Double
    let initialWeight: Double
    
    // Состояние интерфейса
    @State private var isDragging = false
    @State private var scrollPosition: CGFloat = 0
    @State private var isInitialized: Bool = false
    @State private var lastTranslation: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    
    // Тактильная обратная связь
    @State private var hapticEngine: CHHapticEngine?
    @State private var lastHapticTime = Date(timeIntervalSince1970: 0)
    private let hapticCooldown: TimeInterval = 0.08
    
    // Константы для отрисовки линейки
    private let tickSpacing: CGFloat = 12
    private let majorTickHeight: CGFloat = 38
    private let mediumTickHeight: CGFloat = 28
    private let minorTickHeight: CGFloat = 18
    private let tickWidth: CGFloat = 1.5
    private let indicatorWidth: CGFloat = 2.5
    private let horizontalLineHeight: CGFloat = 1.5
    
    // Оптимизация для производительности
    private let effectiveStep: Double
    
    // MARK: - Computed Properties
    // Статус изменения веса
    private var weightStatus: String {
        if abs(selectedWeight - initialWeight) < 0.1 {
            return "Maintain weight"
        } else if selectedWeight > initialWeight {
            return "Gain weight"
        } else {
            return "Lose weight"
        }
    }
    
    // MARK: - Initialization
    init(selectedWeight: Binding<Double>, initialWeight: Double, minWeight: Double = 0.0, maxWeight: Double = 250.0, step: Double = 0.1) {
        self._selectedWeight = selectedWeight
        self.initialWeight = initialWeight
        self.minWeight = minWeight
        self.maxWeight = maxWeight
        self.step = step
        
        // Оптимизация шага для больших диапазонов
        if maxWeight - minWeight > 200 {
            self.effectiveStep = 0.5
        } else {
            self.effectiveStep = step
        }
        
        // Рассчитываем ширину содержимого
        let totalTicks = Int((maxWeight - minWeight) / self.effectiveStep) + 1
        let contentWidth = CGFloat(totalTicks) * tickSpacing
        self._contentWidth = State(initialValue: contentWidth)
    }
    
    // MARK: - Main View
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Статус и отображение веса
                VStack(spacing: 6) {
                    // Статус изменения веса
                    Text(weightStatus)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(.easeOut(duration: 0.2), value: weightStatus)
                    
                    // Отображение текущего веса
                    Text(String(format: "%.1f kg", selectedWeight))
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .id("weightValue-\(String(format: "%.1f", selectedWeight))")
                        .contentTransition(.numericText())
                }
                .padding(.bottom, 30)
                
                // Линейка
                rulerView(geometry: geometry)
            }
            .onAppear {
                resetAndInitialize(with: geometry)
            }
            .onChange(of: selectedWeight) { newWeight in
                if isInitialized && !isDragging {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        scrollPosition = calculateScrollPosition(for: newWeight, geometry: geometry)
                    }
                }
            }
            .onChange(of: geometry.size) { _ in
                if isInitialized {
                    scrollPosition = calculateScrollPosition(for: selectedWeight, geometry: geometry)
                }
            }
        }
        .frame(height: 200)
    }
    
    // MARK: - Component Views
    
    // Линейка с указателем
    private func rulerView(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Подсветка области изменения веса
            if isInitialized {
                highlightArea(geometry: geometry)
            }
            
            // Горизонтальная линия
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: geometry.size.width, height: horizontalLineHeight)
                .offset(y: 0)
            
            // Центральный указатель
            indicatorLine
            
            // Содержимое линейки
            rulerContent(geometry: geometry)
        }
        .frame(height: 110)
        .clipped()
    }
    
    // Подсветка области изменения веса
    private func highlightArea(geometry: GeometryProxy) -> some View {
        ZStack {
            if abs(selectedWeight - initialWeight) > 0.05 {
                let initialPosition = calculateScrollPosition(for: initialWeight, geometry: geometry)
                let selectedPosition = scrollPosition
                let width = abs(selectedPosition - initialPosition)
                let start = min(selectedPosition, initialPosition)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: max(width, 4), height: 60)
                    .position(
                        x: start + width / 2,
                        y: 0
                    )
            }
        }
    }
    
    // Центральный указатель
    private var indicatorLine: some View {
        Rectangle()
            .fill(Color.black)
            .frame(width: indicatorWidth, height: 60)
            .offset(y: -30)
    }
    
    // Содержимое линейки (деления и цифры)
    private func rulerContent(geometry: GeometryProxy) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    // Начальный отступ
                    Spacer()
                        .frame(width: geometry.size.width / 2)
                    
                    // Деления линейки
                    ForEach(0..<Int((maxWeight - minWeight) / effectiveStep) + 1, id: \.self) { index in
                        let weight = minWeight + Double(index) * effectiveStep
                        tickView(for: weight)
                    }
                    
                    // Конечный отступ
                    Spacer()
                        .frame(width: geometry.size.width / 2)
                }
            }
            .offset(x: scrollPosition)
            .gesture(dragGesture(geometry: geometry))
            .gesture(tapGesture(geometry: geometry))
        }
        .scrollDisabled(true)
    }
    
    // Отдельное деление линейки
    private func tickView(for weight: Double) -> some View {
        let isMajorTick = weight.truncatingRemainder(dividingBy: 10) == 0
        let isMediumTick = weight.truncatingRemainder(dividingBy: 1) == 0
        
        // Оптимизация для высоких значений веса
        let shouldShowLabel = isMajorTick || 
                             (weight <= 100 && weight.truncatingRemainder(dividingBy: 5) == 0) ||
                             (weight > 100 && weight <= 200 && weight.truncatingRemainder(dividingBy: 10) == 0) ||
                             (weight > 200 && weight.truncatingRemainder(dividingBy: 50) == 0)
        
        return VStack(spacing: 0) {
            if isMajorTick {
                // Основные деления (10, 20, 30...)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: tickWidth, height: majorTickHeight)
                
                if shouldShowLabel {
                    Text("\(Int(weight))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.top, 8)
                } else {
                    Spacer().frame(height: 20)
                }
            } else if isMediumTick {
                // Средние деления (целые числа)
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: tickWidth, height: mediumTickHeight)
                
                // Для средних отметок показываем только каждые 5 значений
                if shouldShowLabel && weight.truncatingRemainder(dividingBy: 5) == 0 {
                    Text("\(Int(weight))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.top, 8)
                } else {
                    Spacer().frame(height: 20)
                }
            } else {
                // Мелкие деления (дробные значения)
                if weight <= 100 {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: tickWidth, height: minorTickHeight)
                } else {
                    Spacer()
                        .frame(width: 0, height: minorTickHeight)
                }
                
                Spacer().frame(height: 20)
            }
        }
        .frame(width: tickSpacing)
    }
    
    // MARK: - Gestures
    
    // Жест перетаскивания
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    lastTranslation = 0
                }
                
                // Вычисляем разницу в перемещении
                let delta = value.translation.width - lastTranslation
                scrollPosition += delta
                lastTranslation = value.translation.width
                
                // Обновляем вес на основе позиции
                updateWeight(for: geometry)
            }
            .onEnded { value in
                // Рассчитываем инерцию
                let velocity = value.predictedEndLocation.x - value.location.x
                let limitedVelocity = max(min(velocity, 800), -800)
                
                // Определяем фактор инерции
                let velocityFactor: CGFloat
                if abs(limitedVelocity) > 500 {
                    velocityFactor = 0.3
                } else if abs(limitedVelocity) > 300 {
                    velocityFactor = 0.25
                } else if abs(limitedVelocity) > 100 {
                    velocityFactor = 0.2
                } else {
                    velocityFactor = 0.15
                }
                
                // Применяем инерцию
                let decelerationDistance = limitedVelocity * velocityFactor
                snapToNearestTick(geometry: geometry, withInertia: decelerationDistance)
                
                // Сбрасываем состояние
                isDragging = false
                lastTranslation = 0
            }
    }
    
    // Жест нажатия для перемещения на конкретную позицию
    private func tapGesture(geometry: GeometryProxy) -> some Gesture {
        TapGesture()
            .onEnded { _ in
                // Обработка не требуется, так как нажатия обрабатываются DragGesture с minimumDistance = 0
            }
    }
    
    // MARK: - Utility Methods
    
    // Начальная инициализация
    private func resetAndInitialize(with geometry: GeometryProxy) {
        // Сброс состояния
        isDragging = false
        lastTranslation = 0
        isInitialized = false
        
        // Инициализация тактильной обратной связи
        prepareHaptics()
        
        // Нормализация и выравнивание веса
        let normalizedWeight = min(max(selectedWeight, minWeight), maxWeight)
        let alignedWeight = alignWeightToGrid(normalizedWeight)
        
        if abs(alignedWeight - selectedWeight) > 0.001 {
            selectedWeight = alignedWeight
        }
        
        // Устанавливаем начальное положение линейки
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            scrollPosition = calculateScrollPosition(for: selectedWeight, geometry: geometry)
            
            // Плавная анимация для начального положения
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                scrollPosition = calculateScrollPosition(for: selectedWeight, geometry: geometry)
            }
            
            // Активируем подсветку
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInitialized = true
            }
        }
    }
    
    // Обновление веса на основе текущей позиции скролла
    private func updateWeight(for geometry: GeometryProxy) {
        // Вычисляем индекс веса на основе позиции
        let centerPoint = geometry.size.width / 2
        let weightIndex = (-scrollPosition + centerPoint) / tickSpacing
        
        // Рассчитываем новый вес
        let rawWeight = minWeight + Double(weightIndex) * effectiveStep
        let alignedWeight = alignWeightToGrid(rawWeight)
        
        // Применяем новый вес
        if abs(alignedWeight - selectedWeight) >= 0.09 {
            selectedWeight = alignedWeight
            provideFeedbackForWeight(alignedWeight)
        }
    }
    
    // Привязка к ближайшему делению с учетом инерции
    private func snapToNearestTick(geometry: GeometryProxy, withInertia inertia: CGFloat = 0) {
        // Рассчитываем целевую позицию с учетом инерции
        let centerPoint = geometry.size.width / 2
        let currentIndex = (-scrollPosition + centerPoint) / tickSpacing
        let targetIndex = currentIndex + inertia / tickSpacing
        
        // Округляем до ближайшего деления
        let roundedIndex = round(targetIndex)
        let targetPosition = -(roundedIndex * tickSpacing - centerPoint)
        
        // Рассчитываем вес для этой позиции
        let targetWeight = minWeight + Double(roundedIndex) * effectiveStep
        let alignedWeight = alignWeightToGrid(targetWeight)
        
        // Определяем тип анимации в зависимости от скорости
            let animation: Animation
        if abs(inertia) > 200 {
            animation = .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.15)
            } else {
            animation = .spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0.2)
            }
            
        // Применяем анимацию и обновляем вес
            withAnimation(animation) {
            scrollPosition = targetPosition
            selectedWeight = alignedWeight
            }
            
        // Добавляем тактильную обратную связь
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            provideFeedbackForWeight(alignedWeight)
        }
    }
    
    // Рассчитываем позицию скролла для заданного веса
    private func calculateScrollPosition(for weight: Double, geometry: GeometryProxy) -> CGFloat {
        let index = (weight - minWeight) / effectiveStep
        return -(CGFloat(index) * tickSpacing) + geometry.size.width / 2
    }
    
    // Выравнивание веса по сетке
    private func alignWeightToGrid(_ weight: Double) -> Double {
        let index = round((weight - minWeight) / effectiveStep)
        let alignedWeight = minWeight + index * effectiveStep
        return min(max(alignedWeight, minWeight), maxWeight).rounded(toPlaces: 1)
    }
    
    // MARK: - Haptic Feedback
    
    // Подготовка тактильной обратной связи
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error creating haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Тактильная обратная связь в зависимости от веса
    private func provideFeedbackForWeight(_ weight: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= hapticCooldown else { return }
        
        lastHapticTime = now
        
        // Определяем интенсивность вибрации
        var intensity: Float = 0.2
        
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            intensity = 0.3
        }
        if weight.truncatingRemainder(dividingBy: 5) == 0 {
            intensity = 0.5
        }
        if weight.truncatingRemainder(dividingBy: 10) == 0 {
            intensity = 0.7
        }
        
        // Используем UIImpactFeedbackGenerator для простой вибрации
        let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.6 ? .medium : .light
        let feedback = UIImpactFeedbackGenerator(style: style)
        feedback.impactOccurred(intensity: CGFloat(intensity))
        
        // Дополнительно используем более продвинутую тактильную обратную связь
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = hapticEngine {
            do {
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpness], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
                // Если не удается использовать CHHapticPattern, не выбрасываем ошибку
            }
        }
    }
}

// MARK: - Extensions

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - Preview
struct WeightRulerPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            WeightRulerPickerView(selectedWeight: .constant(70.0), initialWeight: 65.0)
        }
    }
} 

