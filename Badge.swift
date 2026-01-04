import SwiftUI

struct Badge: View {
    let text: String
    let color: Color
    let labelColor: Color

    enum Size {
        case small
        case big
    }

    let size: Size

    static func color(for text: String) -> Color {
        switch text.lowercased() {
        case "chatgpt":
            return Color(uiColor: .systemGray3.withAlphaComponent(1))
        case "deepseek":
            return Color(uiColor: .systemIndigo.withAlphaComponent(0.8))
        case "gemini":
            return Color(uiColor: .systemBlue.withAlphaComponent(0.8))
        case "claude":
            return Color(uiColor: .systemOrange.withAlphaComponent(0.6))
        case "copilot":
            return Color(uiColor: .systemTeal.withAlphaComponent(0.8))
        case "grok":
            return Color(uiColor: .systemBackground.withAlphaComponent(1))
        case "meta ai", "meta":
            return Color(uiColor: .systemPurple.withAlphaComponent(0.8))
        case "mistral":
            return Color(uiColor: .systemRed.withAlphaComponent(0.8))
        default:
            return .gray
        }
    }

    static func labelColor(for text: String) -> Color {
        // Default to white for strong contrast on the chosen background colors.
        // Override here per type if you adopt lighter backgrounds.
        switch text.lowercased() {
        case "chatgpt", "deepseek", "gemini", "claude", "copilot", "grok", "meta ai", "meta", "mistral":
            return .primary
        default:
            return .primary
        }
    }

    init(text: String, color: Color, size: Size = .small, labelColor: Color? = nil) {
        self.text = text
        self.color = color
        self.size = size
        self.labelColor = labelColor ?? Badge.labelColor(for: text)
    }

    var body: some View {
        Text(text)
            .font(size == .big ? .callout.weight(.semibold) : .caption)
            .foregroundColor(labelColor)
            .padding(.horizontal, size == .big ? 12 : 6)
            .padding(.vertical, size == .big ? 4 : 2)
            .background(color)
            .cornerRadius(16)
    }
}
