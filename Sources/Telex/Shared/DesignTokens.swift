import SwiftUI
import AppKit

enum DesignTokens {
    static let periwinkle = Color(hex: "#8794F2")
    static let violet = Color(hex: "#3938D6")
    static let presets = ["#F5F5FA", "#FEF3C7", "#FACC15", "#38BDF8", "#42E85A", "#A5B4FC"]
}
extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0xF5F5FA
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else { return "#F5F5FA" }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}

extension DesignTokens {
    static func colorName(_ hex: String) -> String {
        switch hex {
        case "#F5F5FA": "Crisp White"
        case "#FEF3C7": "Warm Ivory"
        case "#FACC15": "Studio Yellow"
        case "#38BDF8": "Electric Cyan"
        case "#42E85A": "Neon Mint"
        case "#A5B4FC": "Soft Periwinkle"
        default: "Custom Color"
        }
    }
}
