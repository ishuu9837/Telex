import SwiftUI

struct NotchExtensionShape: Shape {
    var floating: Bool
    var safeTop: Double
    func path(in rect: CGRect) -> Path {
        let radius = min(16.0, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct VoiceBeamVisualView: View {
    var intensity: Double
    var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating || reduceMotion)) { context in
            let level = min(1, max(0, intensity))
            let phase = animating && !reduceMotion ? context.date.timeIntervalSinceReferenceDate * 1.8 : 0
            let breath = sin(phase) * 0.06
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: "#558CFF").opacity(0.8), DesignTokens.violet.opacity(0.7), .clear], center: .center, startRadius: 4, endRadius: 120))
                    .frame(width: 260, height: 110 + level * 25)
                    .blur(radius: 12)
                ForEach(0..<3) { index in
                    let shift = Double(index - 1)
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "#B6CDFF"), Color(hex: "#5789FF").opacity(0.9), DesignTokens.violet.opacity(0.25), .clear], center: .top, startRadius: 0, endRadius: 39))
                        .frame(width: 72 + level * 22, height: 72 + level * 22)
                        .scaleEffect(1 + breath)
                        .blur(radius: 5)
                        .offset(x: shift * 33, y: abs(shift) * 10 + (reduceMotion || !animating ? 0 : sin(phase + Double(index)) * 4))
                }
            }
            .frame(width: 270, height: 120)
            .opacity(0.55 + level * 0.35)
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct PrompterCapsuleView: View {
    @Bindable var model: PrompterViewModel
    var window: WeakPrompterWindow
    @State private var dragOrigin: CGPoint?
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black
                if model.preferences.voiceBeamEnabled {
                    VStack { Spacer(); VoiceBeamVisualView(intensity: model.preferences.voicePacingEnabled ? min(1, max(0, (model.levelDB + 55) / 40)) : 0.25, animating: model.running && !model.manualPaused && !(model.hovering && model.preferences.hoverToPauseEnabled) && model.countdown == 0).offset(y: 30) }
                }
                Group {
                    ZStack(alignment: .top) {
                        if model.preferences.readingBandEnabled {
                            Rectangle().fill(.white.opacity(0.045)).frame(height: model.lineHeight).offset(y: model.lineHeight)
                        }
                        VStack(spacing: 0) {
                            ForEach(model.lines) { line in
                                Text(line.text)
                                    .font(.system(size: line.isCue ? min(13, model.fontSize) : model.fontSize, weight: line.isCue ? .semibold : .medium, design: .monospaced))
                                    .foregroundStyle(line.isCue ? DesignTokens.periwinkle : Color(hex: model.script.customTextColorHex ?? model.preferences.scriptTextColorHex))
                                    .lineLimit(1).minimumScaleFactor(0.6)
                                    .frame(maxWidth: .infinity).frame(height: model.lineHeight)
                                    .opacity(model.preferences.readingBandEnabled && Double(line.id) * model.lineHeight < model.offset ? 0.38 : 1)
                            }
                        }
                        .padding(.horizontal, 20).offset(y: model.lineHeight - model.offset)
                        .scaleEffect(x: model.preferences.mirrorHorizontally ? -1 : 1, y: model.preferences.mirrorVertically ? -1 : 1)
                    }
                    .frame(width: geometry.size.width, height: max(1, geometry.size.height - model.safeTop), alignment: .top)
                    .clipped()
                    .mask(VStack(spacing: 0) { LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom).frame(height: 14); Color.white })
                    .padding(.top, model.safeTop)
                }
                if model.floating && model.hovering {
                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.5)).frame(width: 38, height: 4).padding(.top, 7).padding(.horizontal, 15)
                        .contentShape(Rectangle()).help("Drag to move floating prompter")
                        .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                            if dragOrigin == nil { dragOrigin = window.panel?.frame.origin }
                            if let origin = dragOrigin { window.moveFloating(by: value.translation, startingAt: origin) }
                        }.onEnded { _ in dragOrigin = nil })
                }
                if model.preferences.clickThroughEnabled {
                    Text("Click-through on · ⇧⌘L to unlock").font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.orange).padding(6).background(.black.opacity(0.9), in: Capsule())
                        .padding(.top, max(6, model.safeTop)).allowsHitTesting(false)
                }
                if model.countdown > 0 { CountdownOverlayView(remaining: model.countdown).padding(.top, model.safeTop) }
                if (model.hovering || model.manualPaused || !model.running) && model.countdown == 0 {
                    VStack { Spacer(); HoverPauseOverlayView(model: model, window: window).padding(.bottom, 7) }.padding(.horizontal, 10)
                }
                VStack { Spacer(); HStack { Spacer(); Image(systemName: "arrow.down.right").font(.system(size: 10)).foregroundStyle(.white.opacity(model.hovering ? 0.5 : 0.01)).frame(width: 24, height: 24).contentShape(Rectangle())
                    .gesture(DragGesture().onChanged { value in window.resize(translation: value.translation, horizontal: true, vertical: true) }.onEnded { _ in window.endResize() })
                    .accessibilityLabel("Resize prompter; size controls are also in the inspector")
                } }
            }
            .clipShape(NotchExtensionShape(floating: model.floating, safeTop: model.safeTop))
        }
        .onHover { model.hovering = $0 }
        .preferredColorScheme(.dark)
    }
}
