import SwiftUI

struct WeekCalendarView: View {
    let days = ["W", "T", "F", "S", "S", "M", "T"]
    let dates = ["9", "10", "11", "12", "13", "14", "15"]
    @State private var selectedIndex = 5 // По умолчанию выбран понедельник (14)
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(0..<7) { index in
                    VStack(spacing: 8) {
                        Text(days[index])
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            Circle()
                                .strokeBorder(style: StrokeStyle(
                                    lineWidth: 1,
                                    dash: [3]
                                ))
                                .frame(width: 35, height: 35)
                                .foregroundColor(selectedIndex == index ? .primary : .secondary.opacity(0.5))
                            
                            if selectedIndex == index {
                                Circle()
                                    .strokeBorder(style: StrokeStyle(
                                        lineWidth: 2,
                                        dash: [3]
                                    ))
                                    .frame(width: 35, height: 35)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Text(dates[index])
                            .font(.system(size: 16))
                    }
                    .onTapGesture {
                        selectedIndex = index
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct WeekCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        WeekCalendarView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
