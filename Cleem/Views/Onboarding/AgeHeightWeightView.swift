import SwiftUI

struct AgeHeightWeightView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var ageSliderValue: Double = 30
    @State private var heightSliderValue: Double = 170
    @State private var currentWeightSliderValue: Double = 70
    @State private var targetWeightSliderValue: Double = 65
    @State private var showSecondSection = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    // Constants for slider ranges
    private let ageRange: ClosedRange<Double> = 12...100
    private let heightRange: ClosedRange<Double> = 130...220 // cm
    private let weightRange: ClosedRange<Double> = 40...200 // kg
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Text("Your Body Metrics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("We'll use this to calculate your nutritional needs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // First section - Age and Height
                VStack(spacing: 25) {
                    // Age slider
                    MetricSlider(
                        value: $ageSliderValue,
                        range: ageRange,
                        title: "Age",
                        unit: "years",
                        displayValue: "\(Int(ageSliderValue))",
                        step: 1,
                        onChange: { newValue in
                            navigationCoordinator.userProfile.age = Int(newValue)
                        }
                    )
                    
                    // Height slider
                    MetricSlider(
                        value: $heightSliderValue,
                        range: heightRange,
                        title: "Height",
                        unit: "cm",
                        displayValue: String(format: "%.0f", heightSliderValue),
                        step: 1,
                        onChange: { newValue in
                            navigationCoordinator.userProfile.heightInCm = Int(newValue)
                        }
                    )
                }
                .opacity(1)
                
                // Second section - Weight
                VStack(spacing: 25) {
                    // Current weight slider
                    MetricSlider(
                        value: $currentWeightSliderValue,
                        range: weightRange,
                        title: "Current Weight",
                        unit: "kg",
                        displayValue: String(format: "%.1f", currentWeightSliderValue),
                        step: 0.1,
                        onChange: { newValue in
                            navigationCoordinator.userProfile.weightInKg = newValue
                        }
                    )
                    
                    // Target weight slider
                    MetricSlider(
                        value: $targetWeightSliderValue,
                        range: weightRange,
                        title: "Target Weight",
                        unit: "kg",
                        displayValue: String(format: "%.1f", targetWeightSliderValue),
                        step: 0.1,
                        onChange: { newValue in
                            navigationCoordinator.userProfile.targetWeightInKg = newValue
                        }
                    )
                }
                .padding(.top, 10)
                .opacity(showSecondSection ? 1 : 0)
                .offset(y: showSecondSection ? 0 : 50)
                
                Spacer(minLength: 20)
                
                // Continue button
                Button(action: {
                    navigationCoordinator.userProfile.age = Int(ageSliderValue)
                    navigationCoordinator.userProfile.heightInCm = Int(heightSliderValue)
                    navigationCoordinator.userProfile.weightInKg = currentWeightSliderValue
                    navigationCoordinator.userProfile.targetWeightInKg = targetWeightSliderValue
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .overlay(
            VStack {
                HStack {
                    Button(action: onBack) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .padding(.top, 20)
                
                Spacer()
            }
        )
        .onAppear {
            // Initialize values from profile
            ageSliderValue = Double(navigationCoordinator.userProfile.age)
            heightSliderValue = Double(navigationCoordinator.userProfile.heightInCm)
            currentWeightSliderValue = navigationCoordinator.userProfile.weightInKg
            targetWeightSliderValue = navigationCoordinator.userProfile.targetWeightInKg
            
            // Animate the second section after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSecondSection = true
                }
            }
        }
    }
}

struct MetricSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let title: String
    let unit: String
    let displayValue: String
    let step: Double
    let onChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title and current value
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(displayValue) \(unit)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            // Slider
            Slider(value: $value, in: range, step: step)
                .accentColor(.blue)
                .onChange(of: value) { oldValue, newValue in
                    DispatchQueue.main.async {
                        onChange(newValue)
                    }
                }
            
            // Min and max labels
            HStack {
                Text("\(Int(range.lowerBound))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(range.upperBound))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct AgeHeightWeightView_Previews: PreviewProvider {
    static var previews: some View {
        AgeHeightWeightView(onContinue: {}, onBack: {})
            .environmentObject(NavigationCoordinator.shared)
    }
} 