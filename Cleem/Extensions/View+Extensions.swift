import SwiftUI

// Commenting out this functionality as it conflicts with ViewExtensions.swift
// This extension has been moved to ViewExtensions.swift
// If both implementations are needed, please use different names
/*
extension View {
    func cornerRadiusWithCorners(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Вспомогательная форма для создания скругленных углов
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
} 
*/ 