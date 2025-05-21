import SwiftUI

struct StepsCard: View {
    var steps: Int = 0
    var targetSteps: Int = 10000
    var caloriesBurned: Int = 0
    
    var body: some View {
        HStack(spacing: 10) {
            // Левая карточка - шаги
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(steps)")
                        .font(.system(size: 32, weight: .bold))
                    Text("/\(targetSteps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Steps today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        
                        Text("Connect Apple Health to track your steps")
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(15)
            
            // Правая карточка - сожженные калории
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame")
                        .foregroundColor(.orange)
                    
                    Text("\(caloriesBurned)")
                        .font(.system(size: 32, weight: .bold))
                }
                
                Text("Calories burned")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Image(systemName: "figure.run")
                        .padding(5)
                        .background(Color.black)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                    
                    Text("Steps")
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("+\(caloriesBurned)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
    }
}

struct StepsCard_Previews: PreviewProvider {
    static var previews: some View {
        StepsCard()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
