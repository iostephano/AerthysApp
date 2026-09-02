import SwiftUI
import UIKit

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var analysisFrameSide: CGFloat = 260

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.cameraService.session)
                .ignoresSafeArea()

            if viewModel.cameraService.permissionState == .denied {
                permissionDeniedView
            } else if viewModel.state == .result, let assessment = viewModel.assessment {
                ResultView(assessment: assessment, onScanAnother: viewModel.resetToCamera)
                    .transition(.opacity)
            } else if viewModel.state == .noLichen {
                RejectionOverlayView(onRetry: viewModel.resetToCamera)
                    .transition(.opacity)
            } else {
                scannerOverlay
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { analysisFrameSide = AnalysisRegion.frameSide(forContainerWidth: geo.size.width) }
                    .onChange(of: geo.size.width) { analysisFrameSide = AnalysisRegion.frameSide(forContainerWidth: $0) }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { newPhase in
            viewModel.handleScenePhaseChange(isActive: newPhase == .active)
        }
        .sheet(isPresented: $viewModel.isInfoPresented) {
            InfoView()
        }
    }

    private var scannerOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            centralAnalysisArea
            Spacer()
            scanButton
                .padding(.bottom, 24)
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                infoButton
                Spacer()
                TorchButton(
                    isOn: viewModel.cameraService.isTorchOn,
                    isEnabled: viewModel.cameraService.isTorchAvailable,
                    action: viewModel.toggleTorch
                )
            }

            titleBlock
                .padding(.leading, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Aerthys")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("Eco-escáner de calidad del aire")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var infoButton: some View {
        let isDisabled = viewModel.state == .scanning
        return Button {
            viewModel.isInfoPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.25), value: isDisabled)
        .accessibilityLabel("Cómo funciona Aerthys")
    }

    private var centralAnalysisArea: some View {
        VStack(spacing: 16) {
            if viewModel.state == .scanning {
                Text("ANÁLISIS VISUAL")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(2)
                    .foregroundStyle(Color.aerthysAccent.opacity(0.85))
                    .transition(.opacity)
            }

            ZStack {
                AnalysisFrameView(state: viewModel.state, reduceMotion: reduceMotion, size: analysisFrameSide)

                AnalysisParticlesView(isActive: viewModel.state == .scanning, reduceMotion: reduceMotion)

                ScanLineView(isActive: viewModel.state == .scanning, reduceMotion: reduceMotion)
            }
            .frame(width: analysisFrameSide, height: analysisFrameSide)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(viewModel.statusText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.statusText)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
    }

    private var scanButton: some View {
        Button {
            viewModel.startScan()
        } label: {
            HStack(spacing: 10) {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(viewModel.isBusy ? "ANALIZANDO" : "ESCANEAR")
                    .font(.headline)
                    .fontWeight(.bold)
                    .tracking(1.2)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(Color.aerthysAccent))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .padding(.horizontal, 32)
        .disabled(!viewModel.cameraService.isSessionRunning || viewModel.isBusy)
        .opacity((viewModel.cameraService.isSessionRunning && !viewModel.isBusy) ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isBusy)
        .accessibilityLabel(viewModel.isBusy ? "Analizando muestra" : "Escanear líquen")
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.8))

            Text("Se necesita acceso a la cámara")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Aerthys necesita la cámara trasera para analizar visualmente el líquen. Actívala desde Ajustes para continuar.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Abrir Ajustes")
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    ScannerView()
}
