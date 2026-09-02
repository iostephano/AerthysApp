import SwiftUI

struct AnalysisParticlesView: View {
    let isActive: Bool
    let reduceMotion: Bool

    private struct Node {
        let x: CGFloat
        let y: CGFloat
        let delay: Double
    }

    private static let nodes: [Node] = [
        Node(x: 0.22, y: 0.28, delay: 0.00),
        Node(x: 0.68, y: 0.20, delay: 0.15),
        Node(x: 0.82, y: 0.50, delay: 0.30),
        Node(x: 0.62, y: 0.78, delay: 0.10),
        Node(x: 0.28, y: 0.74, delay: 0.25),
        Node(x: 0.14, y: 0.54, delay: 0.40),
        Node(x: 0.48, y: 0.42, delay: 0.20),
        Node(x: 0.56, y: 0.60, delay: 0.05),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(Self.nodes.enumerated()), id: \.offset) { _, node in
                    Circle()
                        .fill(Color.aerthysAccent)
                        .frame(width: 4, height: 4)
                        .position(x: proxy.size.width * node.x, y: proxy.size.height * node.y)
                        .opacity(isActive ? (reduceMotion ? 0.75 : 0.9) : 0)
                        .scaleEffect(isActive && !reduceMotion ? 1.25 : 1)
                        .animation(
                            isActive && !reduceMotion
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(node.delay)
                                : .easeInOut(duration: 0.25),
                            value: isActive
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.black
        AnalysisParticlesView(isActive: true, reduceMotion: false)
            .frame(width: 260, height: 260)
    }
}
