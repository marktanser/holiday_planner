import SwiftUI
import UIKit

extension UIColor {
    /// Reads "#rrggbb".
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xff) / 255,
                  green: CGFloat((value >> 8) & 0xff) / 255,
                  blue: CGFloat(value & 0xff) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

/// The rounded panel used for each section.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// A money amount with its currency symbol in front.
struct MoneyField: View {
    let currency: String
    @Binding var value: Double
    var width: CGFloat = 84

    var body: some View {
        HStack(spacing: 4) {
            Text(currency).foregroundStyle(.secondary)
            TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .frame(width: width)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A date in a small rounded outline, e.g. "Sat 15 May".
struct DatePill: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
}

/// A vertical dashed line linking travel to the stays either side.
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// A short message that appears at the bottom of the screen and fades away.
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
    }
}

/// A file ready to hand to the share sheet.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// The system share sheet, where "Save to Files", Mail, Messages and printing live.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
