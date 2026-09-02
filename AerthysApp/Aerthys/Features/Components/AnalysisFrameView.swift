import SwiftUI

struct AnalysisFrameView: View {
    let state: AnalysisState
    let reduceMotion: Bool

    var size: CGFloat = 260
    private let cornerLength: CGFloat = 26
    private let cornerThickness: CGFloat = 3

    private var isActive: Bool { state == .detecting || state == .scanning }
    private var isScanning: Bool { state == .scanning }

    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        return state == .detecting ? 1.025 : 1.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.05 : 0.03))

            ReticleGridView()
                .opacity(isActive ? 0.22 : 0.10)

            ForEach(Corner.allCases, id: \.self) { corner in
                CornerBracket()
                    .stroke(Color.aerthysAccent, style: StrokeStyle(lineWidth: cornerThickness, lineCap: .round))
                    .frame(width: cornerLength, height: cornerLength)
                    .rotationEffect(corner.rotation)
                    .frame(width: size, height: size, alignment: corner.alignment)
                    .padding(10)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .shadow(color: Color.aerthysAccent.opacity(isScanning ? 0.35 : 0), radius: isScanning ? 10 : 0)
        .animation(.easeInOut(duration: 0.35), value: state)
    }
}

private enum Corner: CaseIterable {
    case topLeading, topTrailing, bottomTrailing, bottomLeading

    var rotation: Angle {
        switch self {
        case .topLeading: .degrees(0)
        case .topTrailing: .degrees(90)
        case .bottomTrailing: .degrees(180)
        case .bottomLeading: .degrees(270)
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomTrailing: .bottomTrailing
        case .bottomLeading: .bottomLeading
        }
    }
}

private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct ReticleGridView: View {
    private let fractions: [CGFloat] = [0.25, 0.5, 0.75]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(fractions.enumerated()), id: \.offset) { _, rowFraction in
                ForEach(Array(fractions.enumerated()), id: \.offset) { _, colFraction in
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2, height: 2)
                        .position(x: proxy.size.width * colFraction, y: proxy.size.height * rowFraction)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        AnalysisFrameView(state: .scanning, reduceMotion: false)
    }
}
