import SwiftUI
import AppKit

@main
struct MokuViewApp: App {
    @State private var store = FileStore()
    @State private var navigationState = NavigationState()
    @State private var trashState = TrashState()
    @State private var pieChartState = PieChartState()
    
    @State private var navigationController: NavigationController?
    @State private var trashController: TrashController?
    @State private var pieChartController: PieChartController?

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let nc = navigationController, let tc = trashController, let pc = pieChartController, store.rootNode != nil {
                    MainSplitView(
                        store: store,
                        navigationState: navigationState,
                        trashState: trashState,
                        navigationController: nc,
                        trashController: tc,
                        pieChartController: pc
                    )
                        .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
                        .onAppear {
                            if navigationState.selection == nil {
                                nc.setSelection(store.rootNode?.id)
                            }
                        }
                } else {
                    VStack(spacing: UIConstants.General.xlSpacing) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading Macintosh HD...")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: UIConstants.Window.minWidth, height: UIConstants.Window.minHeight)
                    .onAppear {
                        store.startScan(url: URL(fileURLWithPath: "/"))
                        // Initialize Controllers after starting scan
                        pieChartController = PieChartController(state: pieChartState, store: store)
                        navigationController = NavigationController(state: navigationState, store: store)
                        trashController = TrashController(state: trashState, store: store, navigationState: navigationState)
                    }
                }
            }
        }
    }
}
