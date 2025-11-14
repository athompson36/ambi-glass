import SwiftUI

struct GlassBackground: View {
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        if theme.highContrast {
            LinearGradient(colors: [Color(red:0.02, green:0.02, blue:0.05),
                                    Color(red:0.05, green:0.01, blue:0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        } else {
            LinearGradient(colors: [Color(red:0.06, green:0.07, blue:0.15),
                                    Color(red:0.10, green:0.02, blue:0.20)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .overlay(NoisyStars().blendMode(.screen).opacity(0.20))
        }
    }
}

struct GlassCard<Content: View>: View {
    @EnvironmentObject var theme: ThemeManager
    var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.highContrast ? .white.opacity(0.5) : .white.opacity(0.2), lineWidth: theme.highContrast ? 2 : 1))
            .shadow(color: theme.highContrast ? .cyan.opacity(0.5) : .cyan.opacity(0.25), radius: theme.highContrast ? 15 : 10, x: 0, y: 6)
    }
}

struct NeonButtonStyle: ButtonStyle {
    var highContrast: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(configuration.isPressed ? .cyan : (highContrast ? .white.opacity(0.6) : .white.opacity(0.25)), lineWidth: highContrast ? 2 : 1.5))
            .shadow(radius: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct ThemedButton: View {
    @EnvironmentObject var theme: ThemeManager
    var title: String
    var action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
    }
}

struct MeterBar: View {
    @EnvironmentObject var theme: ThemeManager
    var value: CGFloat // 0...1
    var peakHold: CGFloat = 0 // Peak hold value
    var body: some View {
        GeometryReader { geo in
            let h = max(2, value * geo.size.height)
            let peakHoldH = peakHold > 0 ? max(2, peakHold * geo.size.height) : 0
            
            ZStack(alignment: .bottom) {
                // dB graduations - positioned from bottom (0dB at top, -40dB at bottom)
                ForEach([-40, -30, -20, -12, -6, -3, 0], id: \.self) { db in
                    // Convert dB to linear (0-1 range where 0dB = 1.0, -40dB ≈ 0.01)
                    let linearValue = pow(10.0, Double(db) / 20.0)
                    // Position from bottom: 0dB at top (height), -40dB at bottom (0)
                    let yPosition = CGFloat(linearValue) * geo.size.height
                    
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: geo.size.width - 25, height: 1)
                        Text("\(db)")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 20, alignment: .leading)
                    }
                    .offset(y: -yPosition) // Offset from bottom (negative = up)
                }
                
                // Main meter bar
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: theme.highContrast ? [.cyan, .blue] : [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                        .frame(height: h)
                        .shadow(color: theme.highContrast ? .cyan.opacity(0.8) : .purple.opacity(0.5), radius: theme.highContrast ? 8 : 6, x: 0, y: 0)
                }
                
                // Peak hold indicator
                if peakHold > 0 {
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.yellow.opacity(0.8))
                            .frame(width: geo.size.width, height: 2)
                            .offset(y: -peakHoldH)
                            .shadow(color: .yellow.opacity(0.6), radius: 2)
                    }
                }
            }
        }
    }
}

struct NoisyStars: View {
    var body: some View {
        Canvas { ctx, size in
            let count = 200
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let r = CGFloat.random(in: 0.5...1.5)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.15)))
            }
        }
    }
}

struct ProgressIndicator: View {
    @EnvironmentObject var theme: ThemeManager
    var progress: Double // 0...1
    var message: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            if !message.isEmpty {
                Text(message).font(.footnote).opacity(0.8)
            }
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: theme.highContrast ? .cyan : .purple))
                .frame(height: 8)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
