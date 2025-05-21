import SwiftUI

struct ProgressBarView: View {
    let currentStep: Int
    let totalSteps: Int
    @State private var animateProgress = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Полоска прогресса
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фон полоски (белый)
                    Capsule()
                        .fill(Color.white)
                        .frame(height: 3)
                    
                    // Заполненная часть (черная)
                    ZStack(alignment: .trailing) {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: animateProgress ? geometry.size.width * (CGFloat(currentStep) / CGFloat(totalSteps)) : 0, height: 3)
                            .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateProgress)
                        
                        // Круглый наконечник прогресса
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                            .offset(x: 3, y: 0)
                            .opacity(animateProgress ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3).delay(0.7), value: animateProgress)
                    }
                }
            }
            .frame(height: 3)
        }
        .onAppear {
            // Delay the animation slightly to make it more noticeable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateProgress = true
            }
        }
    }
}

struct ProgressBarView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.91, green: 0.97, blue: 1.0)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: {}) {
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
                    ProgressBarView(currentStep: 2, totalSteps: 8)
                        .padding(.leading, 10)
                        .padding(.trailing, 20)
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
    }
} 