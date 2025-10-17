import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StatusView()
                .tabItem {
                    Label("Status", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)
            
            ConfigurationView()
                .tabItem {
                    Label("Configuration", systemImage: "gear")
                }
                .tag(1)
            
            RulesTestView()
                .tabItem {
                    Label("Test Rules", systemImage: "checkmark.shield")
                }
                .tag(2)
        }
        .onAppear {
            vpnManager.loadConfiguration()
        }
    }
}