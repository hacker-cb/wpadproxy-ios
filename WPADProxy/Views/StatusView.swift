import SwiftUI
import NetworkExtension

struct StatusView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var connectionLogs: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                statusCard
                
                connectionToggle
                
                logsSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("WPAD Proxy")
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(vpnManager.connectionStatus)
                    .font(.headline)
                
                Spacer()
            }
            
            if vpnManager.isConnected {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PAC URL:")
                            .foregroundColor(.secondary)
                        Text(vpnManager.pacURL ?? "Auto-discovery")
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Active Proxy:")
                            .foregroundColor(.secondary)
                        Text(vpnManager.activeProxy ?? "DIRECT")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionToggle: some View {
        Button(action: {
            if vpnManager.isConnected {
                vpnManager.disconnect()
            } else {
                vpnManager.connect()
            }
        }) {
            HStack {
                Image(systemName: vpnManager.isConnected ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(vpnManager.isConnected ? "Disconnect" : "Connect")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(vpnManager.isConnected ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connection Logs")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    connectionLogs.removeAll()
                }
                .font(.caption)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(connectionLogs.indices, id: \.self) { index in
                        Text(connectionLogs[index])
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var statusColor: Color {
        switch vpnManager.connectionStatus {
        case "Connected":
            return .green
        case "Connecting...", "Disconnecting...":
            return .orange
        default:
            return .gray
        }
    }
}