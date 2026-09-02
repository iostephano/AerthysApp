import SwiftUI

struct ScanLineView: View {
    let isActive: Bool
    let reduceMotion: Bool

    private let lineHeight: CGFloat = 2
    private let glowHeight: CGFloat = 56
    private let edgeInset: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let top = edgeInset + lineHeight / 2
            let bottom = max(top, proxy.size.height - edgeInset - lineHeight / 2)
            let y = reduceMotion ? (top + bottom) / 2 : (isActive ? bottom : top)

            ZStack {
                LinearGradient(
                    colors: [.clear, Color.aerthysAccent.opacity(0.5), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: glowHeight)

                Rectangle()
                    .fill(Color.aerthysAccent)
                    .frame(height: lineHeight)
                    .shadow(color: Color.aerthysAccent.opacity(0.7), radius: 5)
            }
            .frame(width: proxy.size.width)
            .position(x: proxy.size.width / 2, y: y)
            .animation(
                isActive && !reduceMotion
                    ? .easeInOut(duration: 1.05).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.25),
                value: isActive
            )
        }
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: isActive)
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.black
        ScanLineView(isActive: true, reduceMotion: false)
            .frame(width: 260, height: 260)
    }
}
