import SwiftUI

struct RejectionOverlayView: View {
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Text("No se reconoció la muestra")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Centra una de las muestras dentro del área de análisis e inténtalo nuevamente.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onRetry) {
                    Text("INTENTAR DE NUEVO")
                        .font(.headline)
                        .fontWeight(.bold)
                        .tracking(1.2)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Capsule().fill(Color.aerthysAccent))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .accessibilityLabel("Intentar de nuevo")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RejectionOverlayView(onRetry: {})
}
