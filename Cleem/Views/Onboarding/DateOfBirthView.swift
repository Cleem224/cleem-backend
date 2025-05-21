import SwiftUI
import CoreHaptics

struct DateOfBirthView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var birthDate: Date
    @State private var showingDatePicker = false
    @State private var formattedDate = ""
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showYearPicker = false
    @State private var showMonthYearPicker = false
    @State private var initialScroll = true
    @State private var hapticEngine: CHHapticEngine?
    @State private var animateItems = false
    var onContinue: () -> Void
    var onBack: () -> Void
    
    // Специальный форматтер для отображения года без точек
    private let yearFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US") // Используем английскую локаль
        formatter.numberStyle = .none // Без стиля форматирования
        formatter.usesGroupingSeparator = false // Без разделителей групп
        return formatter
    }()
    
    init(onContinue: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onBack = onBack
        
        // Установка даты со значением 21 число текущего месяца и года
        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.day = 21
        let defaultDate = Calendar.current.date(from: components) ?? Date()
        
        // Устанавливаем начальное значение для State переменной
        _birthDate = State(initialValue: defaultDate)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()
    
    private let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()
    
    private let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
    
    // Годы для выбора - от 1900 до текущего года
    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1900...currentYear).reversed()
    }
    
    // Месяцы для выбора
    private var months: [String] {
        let dateFormatter = DateFormatter()
        return dateFormatter.monthSymbols
    }
    
    var body: some View {
        ZStack {
            // Фон экрана - светло-голубой
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Верхняя панель с кнопкой назад и индикатором прогресса
                HStack(spacing: 0) {
                    // Кнопка назад - уменьшенная, как на фото 2
                    Button(action: {
                        triggerHapticFeedback() // Добавляем вибрацию при нажатии
                        navigationCoordinator.navigateTo(.genderSelection) // Используем прямую навигацию
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .scaleEffect(animateItems ? 1.0 : 0.1)
                                .opacity(animateItems ? 1.0 : 0)
                            
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .medium))
                                .opacity(animateItems ? 1.0 : 0)
                                .scaleEffect(animateItems ? 1.0 : 0.5)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1), value: animateItems)
                    }
                    .padding(.leading, 20)
                    
                    // Прогресс бар - как на экране выбора пола
                    ProgressBarView(currentStep: 2, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                }
                .padding(.top, 16)
                
                // Заголовок и подзаголовок - выровнены по центру
                VStack(alignment: .center, spacing: 4) {
                    // Заголовок - расположен по центру
                    Text("Date of birth")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Подзаголовок - также по центру
                    Text("This will be used to create your individual plan")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                Spacer()
                
                // Поле выбора даты - расположенное выше центра экрана
                VStack(alignment: .leading, spacing: 8) {
                    // Надпись "Date" над полем - выравнивание слева
                    Text("Date")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.leading, 6)
                    
                    // Кнопка выбора даты
                    Button(action: {
                        generateFeedback() // Добавляем вибрацию при нажатии
                        showingDatePicker = true
                    }) {
                        HStack {
                            Text(formattedDate.isEmpty ? "Select date" : formattedDate)
                                .foregroundColor(formattedDate.isEmpty ? .gray : .black)
                                .font(.system(size: 20))
                                .padding(.leading, 16)
                            
                            Spacer()
                            
                            Image(systemName: "calendar")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                                .padding(.trailing, 16)
                        }
                        .frame(height: 60)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateItems)
                
                Spacer()
                Spacer()
                
                // Кнопка Continue
                Button(action: {
                    // Сохраняем дату рождения
                    navigationCoordinator.userProfile.dateOfBirth = birthDate
                    navigationCoordinator.userProfile.age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 20
                    // Добавляем вибрацию при нажатии кнопки
                    triggerHapticFeedback()
                    // Переходим к следующему экрану с прямой навигацией
                    navigationCoordinator.navigateTo(.heightWeightSelection)
                }) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
            }
            
            // Накладываем календарь поверх основного экрана
            if showingDatePicker {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingDatePicker = false
                        showYearPicker = false
                        showMonthYearPicker = false
                    }
                
                // Отображение выбора месяца и года в виде wheel picker
                if showMonthYearPicker {
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 10)
                        
                        VStack(spacing: 0) {
                            // Заголовок с месяцем и кнопкой закрытия
                            HStack {
                                Text("Select date")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Wheel picker для выбора месяца и года в одной строке
                            HStack(spacing: 0) {
                                // Месяц
                                Picker("Month", selection: $selectedMonth) {
                                    ForEach(1...12, id: \.self) { month in
                                        Text(monthFormatter.string(from: Calendar.current.date(from: DateComponents(year: 2039, month: month, day: 1)) ?? Date()))
                                            .tag(month)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(height: 160)
                                .clipped()
                                .frame(width: (UIScreen.main.bounds.width - 80) / 2)
                                
                                // Год
                                Picker("Year", selection: $selectedYear) {
                                    ForEach(years, id: \.self) { year in
                                        Text(yearFormatter.string(from: NSNumber(value: year)) ?? "\(year)")
                                            .tag(year)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(height: 160)
                                .clipped()
                                .frame(width: (UIScreen.main.bounds.width - 80) / 2)
                            }
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    showMonthYearPicker = false
                                }) {
                                    Text("Cancel")
                                        .foregroundColor(.black)
                                }
                                .padding()
                                
                                Button(action: {
                                    updateBirthDate()
                                    showMonthYearPicker = false
                                    generateFeedback() // Добавляем вибрацию при нажатии Done
                                }) {
                                    Text("Done")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                }
                                .padding()
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .frame(width: UIScreen.main.bounds.width - 40, height: 300)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 20)
                    .onAppear {
                        // Задаем начальные значения
                        selectedMonth = Calendar.current.component(.month, from: birthDate)
                        selectedYear = Calendar.current.component(.year, from: birthDate)
                    }
                } else {
                    // Отображение календаря в стиле как на фото
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 10)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Заголовок месяца и года с возможностью открыть выбор года
                            Button(action: {
                                showMonthYearPicker = true
                            }) {
                                HStack {
                                    Text("\(monthYearFormatter.string(from: birthDate))")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.black)
                                }
                                .padding([.top, .horizontal])
                            }
                            
                            // Дни недели
                            HStack(spacing: 0) {
                                ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { day in
                                    Text(day)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Сетка с днями
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                                ForEach(daysInMonth(), id: \.self) { day in
                                    if day == 0 {
                                        // Пустая ячейка для выравнивания календаря
                                        Text("")
                                            .frame(width: 36, height: 36)
                                    } else {
                                        // Ячейка с днем
                                        Button(action: {
                                            selectDay(day)
                                            formattedDate = dateFormatter.string(from: birthDate)
                                            showingDatePicker = false
                                        }) {
                                            ZStack {
                                                if isDaySelected(day) {
                                                    Circle()
                                                        .fill(Color.black)
                                                        .frame(width: 36, height: 36)
                                                }
                                                
                                                Text("\(day)")
                                                    .font(.body)
                                                    .fontWeight(isDaySelected(day) ? .bold : .regular)
                                                    .foregroundColor(isDaySelected(day) ? .white : .black)
                                            }
                                        }
                                        .frame(width: 36, height: 36)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Кнопки для навигации по месяцам
                            HStack {
                                Button(action: {
                                    previousMonth()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 50, height: 50)
                                            
                                            Image(systemName: "chevron.left")
                                                .foregroundColor(.black)
                                                .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    nextMonth()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 50, height: 50)
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.black)
                                                .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .padding(.vertical)
                    }
                    .frame(width: UIScreen.main.bounds.width - 40, height: 450)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Проверяем текущую дату рождения из профиля, если она есть
            if let existingDOB = navigationCoordinator.userProfile.dateOfBirth {
                birthDate = existingDOB
            }
            
            // Обновляем отображаемую дату
            formattedDate = dateFormatter.string(from: birthDate)
            
            // Подготовка haptic feedback
            prepareHaptics()
            
            // Запускаем анимацию появления элементов с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateItems = true
            }
        }
    }
    
    // Функция для создания тактильной обратной связи (вибрации)
    private func generateFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Простая вибрация для нажатия кнопок
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Метод для подготовки haptic feedback
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }
    
    // Получение последнего дня месяца
    private func lastDayOfMonth() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: birthDate)
        let date = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.upperBound - 1
    }
    
    // Предыдущий месяц
    private func previousMonth() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: birthDate)
        var newComponents = DateComponents()
        
        // Если месяц январь, переходим на декабрь предыдущего года
        if components.month == 1 {
            newComponents.year = components.year! - 1
            newComponents.month = 12
        } else {
            newComponents.year = components.year
            newComponents.month = components.month! - 1
        }
        
        // Устанавливаем тот же день или последний день месяца, если текущий день больше
        let lastDay = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: newComponents)!)!.count
        newComponents.day = min(components.day!, lastDay)
        
        if let newDate = Calendar.current.date(from: newComponents) {
            birthDate = newDate
            generateFeedback()
        }
    }
    
    // Следующий месяц
    private func nextMonth() {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: birthDate)
        var newComponents = DateComponents()
        
        // Если месяц декабрь, переходим на январь следующего года
        if components.month == 12 {
            newComponents.year = components.year! + 1
            newComponents.month = 1
        } else {
            newComponents.year = components.year
            newComponents.month = components.month! + 1
        }
        
        // Устанавливаем тот же день или последний день месяца, если текущий день больше
        let lastDay = Calendar.current.range(of: .day, in: .month, for: Calendar.current.date(from: newComponents)!)!.count
        newComponents.day = min(components.day!, lastDay)
        
        if let newDate = Calendar.current.date(from: newComponents) {
            birthDate = newDate
            generateFeedback()
        }
    }
    
    // Получение массива дней для отображения в календаре
    private func daysInMonth() -> [Int] {
        let calendar = Calendar.current
        let year = Calendar.current.component(.year, from: birthDate)
        let month = Calendar.current.component(.month, from: birthDate)
        
        let dateComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: dateComponents)!
        
        let range = calendar.range(of: .day, in: .month, for: date)!
        let numDays = range.count
        
        // Получаем день недели первого дня месяца (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: date)
        
        // Преобразуем в формат где 1 = Monday
        let adjustedFirstWeekday = (firstWeekday + 5) % 7 + 1
        
        // Создаем массив с нулями для пустых ячеек в начале сетки
        var days = Array(repeating: 0, count: adjustedFirstWeekday - 1)
        
        // Добавляем дни месяца
        days += Array(1...numDays)
        
        return days
    }
    
    // Выбор дня
    private func selectDay(_ day: Int) {
        var components = Calendar.current.dateComponents([.year, .month], from: birthDate)
        components.day = day
        if let date = Calendar.current.date(from: components) {
            birthDate = date
            generateFeedback()
        }
    }
    
    // Проверка, выбран ли день
    private func isDaySelected(_ day: Int) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.day, from: birthDate) == day
    }
    
    // Проверка, является ли день сегодняшним
    private func isToday(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        return false // Отключаем выделение сегодняшней даты
    }
    
    // Обновление даты рождения после изменения месяца или года
    private func updateBirthDate() {
        var components = Calendar.current.dateComponents([.day], from: birthDate)
        components.month = selectedMonth
        components.year = selectedYear
        
        if let date = Calendar.current.date(from: components) {
            birthDate = date
            generateFeedback()
        }
    }
}

struct DateOfBirthView_Previews: PreviewProvider {
    static var previews: some View {
        DateOfBirthView(onContinue: {}, onBack: {})
            .environmentObject(NavigationCoordinator.shared)
    }
} 