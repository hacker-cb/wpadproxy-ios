import Foundation
import NetworkExtension
import CFNetwork

class VPNManager: ObservableObject {
    static let shared = VPNManager()
    
    @Published var connectionStatus = "Disconnected"
    @Published var isConnected = false
    @Published var pacURL: String?
    @Published var activeProxy: String?
    
    private var providerManager: NETunnelProviderManager?
    private var observerToken: Any?
    
    private init() {
        loadConfiguration()
        setupNotifications()
    }
    
    deinit {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    func loadConfiguration() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Failed to load VPN preferences: \(error.localizedDescription)")
                return
            }
            
            self.providerManager = managers?.first(where: { 
                $0.protocolConfiguration?.providerBundleIdentifier == "me.sokolov.wpadproxy.PacketTunnel" 
            })
            
            if self.providerManager == nil {
                self.createVPNConfiguration()
            } else {
                self.updateConnectionStatus()
            }
        }
    }
    
    private func createVPNConfiguration() {
        let providerManager = NETunnelProviderManager()
        let providerProtocol = NETunnelProviderProtocol()
        
        providerProtocol.providerBundleIdentifier = "me.sokolov.wpadproxy.PacketTunnel"
        providerProtocol.serverAddress = "127.0.0.1"
        
        let pacMode = UserDefaults.standard.string(forKey: "pacMode") ?? "auto"
        let pacURL = UserDefaults.standard.string(forKey: "pacURL") ?? ""
        let wpadDomain = UserDefaults.standard.string(forKey: "wpadDomain") ?? "sokolov.me"
        
        providerProtocol.providerConfiguration = [
            "pacMode": pacMode,
            "pacURL": pacURL,
            "wpadDomain": wpadDomain,
            "localProxyPort": 8888
        ]
        
        providerManager.protocolConfiguration = providerProtocol
        providerManager.localizedDescription = "WPAD Proxy"
        providerManager.isEnabled = true
        
        providerManager.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Failed to save VPN configuration: \(error.localizedDescription)")
            } else {
                Logger.log("VPN configuration saved successfully")
                self.providerManager = providerManager
                self.loadConfiguration()
            }
        }
    }
    
    func updateConfiguration() {
        guard let providerManager = providerManager else { return }
        
        let pacMode = UserDefaults.standard.string(forKey: "pacMode") ?? "auto"
        let pacURL = UserDefaults.standard.string(forKey: "pacURL") ?? ""
        let wpadDomain = UserDefaults.standard.string(forKey: "wpadDomain") ?? "sokolov.me"
        
        if let providerProtocol = providerManager.protocolConfiguration as? NETunnelProviderProtocol {
            providerProtocol.providerConfiguration = [
                "pacMode": pacMode,
                "pacURL": pacURL,
                "wpadDomain": wpadDomain,
                "localProxyPort": 8888
            ]
            
            providerManager.saveToPreferences { error in
                if let error = error {
                    Logger.log("Failed to update configuration: \(error.localizedDescription)")
                } else {
                    Logger.log("Configuration updated successfully")
                }
            }
        }
    }
    
    func connect() {
        guard let providerManager = providerManager else {
            createVPNConfiguration()
            return
        }
        
        providerManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.log("Failed to load preferences: \(error.localizedDescription)")
                return
            }
            
            do {
                try providerManager.connection.startVPNTunnel()
                Logger.log("Starting VPN tunnel...")
            } catch {
                Logger.log("Failed to start VPN: \(error.localizedDescription)")
            }
        }
    }
    
    func disconnect() {
        providerManager?.connection.stopVPNTunnel()
        Logger.log("Stopping VPN tunnel...")
    }
    
    private func setupNotifications() {
        observerToken = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateConnectionStatus()
        }
    }
    
    private func updateConnectionStatus() {
        guard let connection = providerManager?.connection else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch connection.status {
            case .connected:
                self.connectionStatus = "Connected"
                self.isConnected = true
                self.fetchActiveProxyInfo()
            case .connecting:
                self.connectionStatus = "Connecting..."
                self.isConnected = false
            case .disconnected:
                self.connectionStatus = "Disconnected"
                self.isConnected = false
                self.activeProxy = nil
            case .disconnecting:
                self.connectionStatus = "Disconnecting..."
                self.isConnected = false
            case .invalid:
                self.connectionStatus = "Invalid Configuration"
                self.isConnected = false
            case .reasserting:
                self.connectionStatus = "Reconnecting..."
                self.isConnected = false
            @unknown default:
                self.connectionStatus = "Unknown"
                self.isConnected = false
            }
            
            Logger.log("VPN Status: \(self.connectionStatus)")
        }
    }
    
    private func fetchActiveProxyInfo() {
        if let session = providerManager?.connection as? NETunnelProviderSession {
            session.sendProviderMessage("getProxyInfo".data(using: .utf8)!) { response in
                if let data = response,
                   let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async { [weak self] in
                        self?.pacURL = info["pacURL"] as? String
                        self?.activeProxy = info["activeProxy"] as? String
                    }
                }
            }
        }
    }
    
    func testPACURL(_ url: String) {
        Logger.log("Testing PAC URL: \(url)")
        
        guard let pacURL = URL(string: url) else {
            Logger.log("Invalid PAC URL")
            return
        }
        
        URLSession.shared.dataTask(with: pacURL) { data, response, error in
            if let error = error {
                Logger.log("PAC URL test failed: \(error.localizedDescription)")
            } else if let data = data, let script = String(data: data, encoding: .utf8) {
                Logger.log("PAC URL test successful, script size: \(script.count) bytes")
            }
        }.resume()
    }
    
    func testWPADDiscovery(domain: String) {
        Logger.log("Testing WPAD discovery for domain: \(domain)")
        WPADDiscovery.discoverWPAD(domain: domain) { pacURL in
            if let pacURL = pacURL {
                Logger.log("WPAD discovered at: \(pacURL)")
                self.testPACURL(pacURL)
            } else {
                Logger.log("WPAD discovery failed for domain: \(domain)")
            }
        }
    }
    
    func evaluatePACForURL(_ urlString: String, completion: @escaping (String?) -> Void) {
        let pacMode = UserDefaults.standard.string(forKey: "pacMode") ?? "auto"
        
        switch pacMode {
        case "manual":
            let pacURLString = UserDefaults.standard.string(forKey: "pacURL") ?? ""
            guard let pacURL = URL(string: pacURLString) else {
                completion(nil)
                return
            }
            PACEvaluator.evaluatePAC(pacURL: pacURL, targetURL: urlString, completion: completion)
            
        case "auto":
            let wpadDomain = UserDefaults.standard.string(forKey: "wpadDomain") ?? "sokolov.me"
            WPADDiscovery.discoverWPAD(domain: wpadDomain) { discoveredURL in
                guard let discoveredURL = discoveredURL,
                      let pacURL = URL(string: discoveredURL) else {
                    completion("DIRECT")
                    return
                }
                PACEvaluator.evaluatePAC(pacURL: pacURL, targetURL: urlString, completion: completion)
            }
            
        case "local":
            let pacScript = UserDefaults.standard.string(forKey: "localPACScript") ?? ""
            guard let targetURL = URL(string: urlString) else {
                completion(nil)
                return
            }
            PACEvaluator.evaluatePACScript(pacScript, targetURL: targetURL, completion: completion)
            
        default:
            completion("DIRECT")
        }
    }
}