import SwiftUI

struct ResultView: View {
    let assessment: AirQualityAssessment
    let onScanAnother: () -> Void

    @State private var showsWhatItMeans = false
    @State private var showsWhatToDo = false

    private var content: ResultContent { ResultContent(for: assessment) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    disclaimer

                    VStack(spacing: 14) {
                        ExpandableCard(title: "¿Qué significa?", accent: content.color, isExpanded: $showsWhatItMeans) {
                            Text(content.whatItMeans)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ExpandableCard(title: "¿Qué puedo hacer?", accent: content.color, isExpanded: $showsWhatToDo) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(content.recommendations, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(content.color)
                                            .frame(width: 5, height: 5)
                                            .padding(.top, 7)
                                        Text(item)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.85))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    scanAnotherButton
                }
                .padding(24)
                .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 16) {
            Text(content.label)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(3)
                .foregroundStyle(content.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().strokeBorder(content.color.opacity(0.5), lineWidth: 1))

            ZStack {
                Circle()
                    .fill(content.color.opacity(0.12))
                    .frame(width: 104, height: 104)
                Circle()
                    .strokeBorder(content.color.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 104, height: 104)
                Image(systemName: content.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(content.color)
            }

            VStack(spacing: 6) {
                Text(content.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(content.visualState)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
    }

    private var disclaimer: some View {
        Text("Estimación basada en el estado visual del bioindicador.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }

    private var scanAnotherButton: some View {
        Button(action: onScanAnother) {
            Text("ESCANEAR OTRO LÍQUEN")
                .font(.headline)
                .fontWeight(.bold)
                .tracking(1.2)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Capsule().fill(Color.aerthysAccent))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .padding(.top, 8)
    }
}

private struct ExpandableCard<Content: View>: View {
    let title: String
    let accent: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }

            if isExpanded {
                content()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ResultContent {
    let label: String
    let title: String
    let visualState: String
    let whatItMeans: String
    let recommendations: [String]
    let color: Color
    let icon: String

    init(for assessment: AirQualityAssessment) {
        switch assessment {
        case .low:
            label = "BAJO"
            title = "Aire con bajos niveles de contaminación"
            visualState = "Liquen con apariencia saludable"
            whatItMeans = "El líquen conserva una apariencia saludable, con coloración y estructura relativamente estables. Esto sugiere bajos niveles de estrés ambiental en el bioindicador."
            recommendations = [
                "Continúa observando periódicamente los líquenes de la zona.",
                "Mantén los espacios exteriores libres de polvo acumulado.",
                "Compara muestras de diferentes lugares.",
            ]
            color = Color(red: 0.4, green: 0.78, blue: 0.5)
            icon = "leaf.fill"

        case .moderate:
            label = "MODERADO"
            title = "Aire moderadamente contaminado"
            visualState = "Liquen con señales de estrés ambiental"
            whatItMeans = "El líquen presenta cambios de coloración como amarillamiento o pardeamiento y señales de estrés. Estas alteraciones pueden relacionarse con condiciones ambientales menos favorables."
            recommendations = [
                "Evita actividad física intensa cuando haya mucho polvo ambiental.",
                "Limpia superficies con un paño húmedo para no levantar partículas.",
                "Mantén ventanas cerradas durante momentos de mayor polvo.",
            ]
            color = Color(red: 0.93, green: 0.73, blue: 0.25)
            icon = "exclamationmark.triangle.fill"

        case .high:
            label = "ALTO"
            title = "Aire con altos niveles de contaminación"
            visualState = "Liquen con deterioro visual severo"
            whatItMeans = "El líquen presenta señales visuales compatibles con un deterioro importante de su estructura y coloración. Esto puede indicar una exposición ambiental más desfavorable."
            recommendations = [
                "Reduce temporalmente actividades prolongadas al aire libre si hay polvo visible.",
                "Mantén puertas y ventanas cerradas durante los momentos más críticos.",
                "Limpia superficies utilizando métodos húmedos.",
                "Considera contrastar el resultado con información ambiental oficial.",
            ]
            color = Color(red: 0.88, green: 0.33, blue: 0.31)
            icon = "exclamationmark.octagon.fill"
        }
    }
}

#Preview("Low") {
    ResultView(assessment: .low, onScanAnother: {})
}

#Preview("Moderate") {
    ResultView(assessment: .moderate, onScanAnother: {})
}

#Preview("High") {
    ResultView(assessment: .high, onScanAnother: {})
}
