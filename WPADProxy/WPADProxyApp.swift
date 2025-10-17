import SwiftUI

@main
struct WPADProxyApp: App {
    @StateObject private var vpnManager = VPNManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
        }
    }
}