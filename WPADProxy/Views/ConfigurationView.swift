import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @AppStorage("pacMode") private var pacMode = "auto"
    @AppStorage("pacURL") private var pacURL = ""
    @AppStorage("wpadDomain") private var wpadDomain = "sokolov.me"
    @AppStorage("useLocalRules") private var useLocalRules = false
    @State private var localPACScript = ""
    @State private var showingPACEditor = false
    
    var body: some View {
        NavigationView {
            Form {
                pacModeSection
                
                if pacMode == "manual" {
                    manualConfigSection
                }
                
                if pacMode == "auto" {
                    autoConfigSection
                }
                
                if pacMode == "local" {
                    localRulesSection
                }
                
                bypassSection
                
                advancedSection
            }
            .navigationTitle("Configuration")
        }
    }
    
    private var pacModeSection: some View {
        Section(header: Text("PAC Mode")) {
            Picker("Mode", selection: $pacMode) {
                Text("Auto-Discovery (WPAD)").tag("auto")
                Text("Manual PAC URL").tag("manual")
                Text("Local Rules").tag("local")
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: pacMode) { _ in
                vpnManager.updateConfiguration()
            }
        }
    }
    
    private var manualConfigSection: some View {
        Section(header: Text("PAC URL")) {
            TextField("http://proxy.example.com/proxy.pac", text: $pacURL)
                .autocapitalization(.none)
                .keyboardType(.URL)
                .onChange(of: pacURL) { _ in
                    vpnManager.updateConfiguration()
                }
            
            if !pacURL.isEmpty {
                Button("Test PAC URL") {
                    vpnManager.testPACURL(pacURL)
                }
            }
        }
    }
    
    private var autoConfigSection: some View {
        Section(header: Text("WPAD Settings")) {
            TextField("Domain", text: $wpadDomain)
                .autocapitalization(.none)
                .keyboardType(.URL)
            
            Text("Will look for: wpad.\(wpadDomain)/wpad.dat")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Test WPAD Discovery") {
                vpnManager.testWPADDiscovery(domain: wpadDomain)
            }
        }
    }
    
    private var localRulesSection: some View {
        Section(header: Text("Local PAC Script")) {
            Toggle("Use Local Rules", isOn: $useLocalRules)
            
            if useLocalRules {
                Button("Edit PAC Script") {
                    showingPACEditor = true
                }
                .sheet(isPresented: $showingPACEditor) {
                    PACEditorView(pacScript: $localPACScript)
                }
                
                if !localPACScript.isEmpty {
                    Text("Script loaded (\(localPACScript.count) characters)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var bypassSection: some View {
        Section(header: Text("Bypass Settings")) {
            Toggle("Bypass for Local Networks", isOn: .constant(true))
                .disabled(true)
            
            Text("Local networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) will bypass proxy")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var advancedSection: some View {
        Section(header: Text("Advanced")) {
            HStack {
                Text("Proxy Port")
                Spacer()
                Text("8888")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("DNS Server")
                Spacer()
                Text("8.8.8.8")
                    .foregroundColor(.secondary)
            }
            
            Toggle("Enable Logging", isOn: .constant(true))
                .disabled(true)
        }
    }
}

struct PACEditorView: View {
    @Binding var pacScript: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Edit PAC JavaScript")
                    .font(.headline)
                    .padding()
                
                TextEditor(text: $pacScript)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                    .padding()
                
                if pacScript.isEmpty {
                    Button("Load Template") {
                        pacScript = """
                        function FindProxyForURL(url, host) {
                            // Bypass proxy for local addresses
                            if (isPlainHostName(host) ||
                                shExpMatch(host, "*.local") ||
                                isInNet(host, "10.0.0.0", "255.0.0.0") ||
                                isInNet(host, "172.16.0.0", "255.240.0.0") ||
                                isInNet(host, "192.168.0.0", "255.255.0.0")) {
                                return "DIRECT";
                            }
                            
                            // Use proxy for everything else
                            return "PROXY proxy.sokolov.me:8080; DIRECT";
                        }
                        """
                    }
                    .padding()
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { dismiss() }
            )
        }
    }
}