import SwiftUI

struct TorchButton: View {
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isOn ? .black : .white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .background(
                    Circle().fill(isOn ? Color.yellow.opacity(0.85) : Color.clear)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(isOn ? 0 : 0.25), lineWidth: 1)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(isOn ? "Apagar luz" : "Encender luz")
    }
}

#Preview {
    ZStack {
        Color.black
        HStack(spacing: 16) {
            TorchButton(isOn: false, isEnabled: true) {}
            TorchButton(isOn: true, isEnabled: true) {}
            TorchButton(isOn: false, isEnabled: false) {}
        }
    }
}
