import SwiftUI

struct WaterIntakeView: View {
    @State private var waterAmount: Double = 0
    let targetAmount: Double = 8 // 8 стаканов
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Water")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Text("\(Int(waterAmount)) fl oz (\(Int(waterAmount/8)) cups)")
                    .font(.title3)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        if waterAmount > 0 {
                            waterAmount -= 8
                        }
                    }) {
                        Image(systemName: "minus")
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    .disabled(waterAmount <= 0)
                    
                    Button(action: {
                        waterAmount += 8
                    }) {
                        Image(systemName: "plus")
                            .padding(8)
                            .background(Color.black)
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct WaterIntakeView_Previews: PreviewProvider {
    static var previews: some View {
        WaterIntakeView()
            .previewLayout(.sizeThatFits)
            .padding(.vertical)
    }
}
