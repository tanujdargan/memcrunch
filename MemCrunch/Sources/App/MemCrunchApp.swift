import SwiftUI

@main
struct MemCrunchApp: App {
    @State private var viewModel = ScanViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Volume...") {
                    viewModel.loadVolumes()
                }
                .keyboardShortcut("o")
            }
            CommandGroup(after: .newItem) {
                Button("Rescan") {
                    if let vol = viewModel.selectedVolume {
                        viewModel.scanVolume(vol)
                    }
                }
                .keyboardShortcut("r")
                .disabled(viewModel.selectedVolume == nil || viewModel.isScanning)

                Button("Cancel Scan") {
                    viewModel.cancelScan()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!viewModel.isScanning)
            }
        }
    }
}
