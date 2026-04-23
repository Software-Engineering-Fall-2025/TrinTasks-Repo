import SwiftUI

enum BrutalStyle {
    static let borderWidth: CGFloat = 2
    static let shadowOffset = CGSize(width: 3, height: 3)
    static let cornerRadius: CGFloat = 4
    static let fontName = "Inter-Regular"
    static let fontNameBold = "Inter-Bold"
    static let fontNameSemiBold = "Inter-SemiBold"

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold: return Font.custom(fontNameBold, size: size)
        case .semibold: return Font.custom(fontNameSemiBold, size: size)
        default: return Font.custom(fontName, size: size)
        }
    }
}

struct BrutalCardModifier: ViewModifier {
    let fillColor: Color
    let borderColor: Color

    func body(content: Content) -> some View {
        content
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: BrutalStyle.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: BrutalStyle.cornerRadius)
                    .stroke(borderColor, lineWidth: BrutalStyle.borderWidth)
            )
            .shadow(
                color: borderColor.opacity(0.9),
                radius: 0,
                x: BrutalStyle.shadowOffset.width,
                y: BrutalStyle.shadowOffset.height
            )
    }
}

extension View {
    func brutalCard(fill: Color, border: Color = .black) -> some View {
        modifier(BrutalCardModifier(fillColor: fill, borderColor: border))
    }
}
