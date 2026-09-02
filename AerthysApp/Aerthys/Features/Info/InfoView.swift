import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    conceptRow(
                        icon: "camera.viewfinder",
                        title: "Observa",
                        text: "Aerthys utiliza la cámara para observar el líquen."
                    )
                    conceptRow(
                        icon: "square.on.square.dashed",
                        title: "Compara",
                        text: "Analiza patrones visuales de coloración y estructura."
                    )
                    conceptRow(
                        icon: "leaf.fill",
                        title: "Estima",
                        text: "Estima el estado del bioindicador y lo relaciona con un nivel orientativo de contaminación ambiental."
                    )

                    Text("Aerthys realiza una estimación visual educativa y no reemplaza un equipo oficial de monitoreo ambiental.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("¿Cómo funciona Aerthys?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func conceptRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(red: 0.4, green: 0.75, blue: 0.6))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    InfoView()
}
