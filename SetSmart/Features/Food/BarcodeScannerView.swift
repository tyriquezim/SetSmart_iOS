import SwiftUI
import Vision
import VisionKit

struct BarcodeScannerView: View {
    var onScan: (String) -> Void
    var onDismiss: () -> Void

    @State private var showManualEntry = false
    @State private var manualCode = ""

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported {
                    if DataScannerViewController.isAvailable {
                        ScannerRepresentable(onScan: onScan)
                            .ignoresSafeArea(edges: .bottom)
                    } else {
                        unavailable("Camera is unavailable. Check permissions in Settings.")
                    }
                } else {
                    unavailable("Barcode scanning is not supported on this device.")
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Manual Entry") { showManualEntry = true }
                }
            }
            .alert("Enter Barcode", isPresented: $showManualEntry) {
                TextField("Barcode number", text: $manualCode)
                    .keyboardType(.numberPad)
                Button("OK") {
                    let code = manualCode.trimmingCharacters(in: .whitespaces)
                    if !code.isEmpty { onScan(code) }
                    manualCode = ""
                }
                Button("Cancel", role: .cancel) { manualCode = "" }
            }
        }
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(Color.ssTextMuted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Scanner wrapper

private struct ScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce, .code128, .qr])
            ],
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        private var pending: String?
        private var fired = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items)
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didUpdate items: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items)
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !fired else { return }
            for item in items {
                if case .barcode(let b) = item, let value = b.payloadStringValue {
                    if value == pending {
                        fired = true
                        HapticsService.loggedSet()
                        onScan(value)
                    } else {
                        pending = value
                    }
                    break
                }
            }
        }
    }
}
