import SwiftUI

struct WaterSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var waterSettings = WaterSettings.shared
    @State private var selectedServingSize: Int
    @Binding var isPresented: Bool
    
    init(isPresented: Binding<Bool>) {
        // Initialize the state with the current serving size
        _selectedServingSize = State(initialValue: WaterSettings.shared.servingSize)
        _isPresented = isPresented
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with X button and title
            HStack {
                Button(action: {
                    // Add haptic feedback when closing
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
                
                Spacer()
                
                Text("Water settings")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Empty view for symmetry
                Color.clear
                    .frame(width: 36, height: 36)
                    .padding(.trailing, 8)
            }
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            // Content
            ScrollView {
                VStack(spacing: 25) {
                    // Serving size selection
                    HStack {
                        Text("Servings size")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        HStack {
                            Text("\(selectedServingSize) ml")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Button(action: {
                                // Switch to the next available serving size without animation
                                let sizes = WaterSettings.availableServingSizes
                                if let currentIndex = sizes.firstIndex(of: selectedServingSize),
                                   let nextSize = sizes[safe: (currentIndex + 1) % sizes.count] {
                                    selectedServingSize = nextSize
                                } else {
                                    // Fallback to first size if not found
                                    selectedServingSize = sizes.first ?? 250
                                }
                                // Haptic feedback
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Number selection list
                    VStack {
                        ZStack {
                            // Background gray bar - match the color of the main card
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray4))
                                .frame(height: 50)
                                .padding(.horizontal)
                            
                            // Selected value with highlight
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(height: 50)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 0)
                                .padding(.horizontal)
                            
                            Text("\(selectedServingSize)")
                                .font(.system(size: 22, weight: .bold))
                        }
                        
                        HStack {
                            // Options list
                            ForEach(WaterSettings.availableServingSizes, id: \.self) { size in
                                Button(action: {
                                    // Set serving size immediately without animation
                                    selectedServingSize = size
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Text("\(size)")
                                        .font(.system(size: 16, weight: selectedServingSize == size ? .bold : .regular))
                                        .foregroundColor(selectedServingSize == size ? .black : .gray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedServingSize == size ?
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            : nil
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 5)
                        
                        Text("ml")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(UIColor.systemGray4))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Water intake recommendations
                    VStack(alignment: .center, spacing: 15) {
                        Text("What is the recommended daily water intake for adequate hydration?")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Individual hydration needs may vary based on factors such as age, activity level, and environment. A general guideline is to consume a minimum of 2000 milliliters (2 liters) of water per day to support optimal physiological function")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.white)
        .onChange(of: selectedServingSize) { newValue in
            waterSettings.updateServingSize(newValue)
        }
        .onDisappear {
            // Save the selected serving size when view disappears
            waterSettings.updateServingSize(selectedServingSize)
        }
    }
}

// Extension to safely access array elements
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct WaterSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WaterSettingsView(isPresented: .constant(true))
    }
} 