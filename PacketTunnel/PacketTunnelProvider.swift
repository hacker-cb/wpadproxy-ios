import NetworkExtension
import Network

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var proxyServer: ProxyServer?
    private var pacEvaluator: PACEvaluator?
    private var configuration: ProxyConfiguration?
    private let localProxyPort: UInt16 = 8888
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        Logger.log("Starting packet tunnel...")
        
        configuration = ProxyConfiguration.load()
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0")
        ]
        settings.ipv4Settings = ipv4Settings
        
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.dnsSettings = dnsSettings
        
        if let providerConfig = protocolConfiguration.providerConfiguration as? [String: Any] {
            configurePAC(from: providerConfig)
        }
        
        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error = error {
                Logger.error("Failed to set tunnel network settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            
            self?.startProxyServer()
            self?.startPacketProcessing()
            
            Logger.log("Packet tunnel started successfully")
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger.log("Stopping packet tunnel, reason: \(reason.rawValue)")
        
        proxyServer?.stop()
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }
        
        Logger.log("Received app message: \(message)")
        
        switch message {
        case "getProxyInfo":
            let info: [String: Any] = [
                "pacURL": configuration?.pacURL ?? "Auto-discovery",
                "activeProxy": proxyServer?.currentProxy ?? "DIRECT"
            ]
            let data = try? JSONSerialization.data(withJSONObject: info)
            completionHandler?(data)
            
        case "getLogs":
            let logs = Logger.getLogs()
            completionHandler?(logs.data(using: .utf8))
            
        case "clearLogs":
            Logger.clearLogs()
            completionHandler?("OK".data(using: .utf8))
            
        default:
            completionHandler?(nil)
        }
    }
    
    private func configurePAC(from config: [String: Any]) {
        let pacMode = config["pacMode"] as? String ?? "auto"
        
        switch pacMode {
        case "manual":
            if let pacURLString = config["pacURL"] as? String {
                Logger.log("Using manual PAC URL: \(pacURLString)")
                setupManualPAC(urlString: pacURLString)
            }
            
        case "auto":
            let wpadDomain = config["wpadDomain"] as? String ?? "sokolov.me"
            Logger.log("Using WPAD auto-discovery for domain: \(wpadDomain)")
            setupWPADDiscovery(domain: wpadDomain)
            
        case "local":
            if let pacScript = config["localPACScript"] as? String {
                Logger.log("Using local PAC script")
                setupLocalPAC(script: pacScript)
            }
            
        default:
            Logger.log("No PAC configuration, using DIRECT connection")
        }
    }
    
    private func setupManualPAC(urlString: String) {
        guard let url = URL(string: urlString) else {
            Logger.error("Invalid PAC URL: \(urlString)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                Logger.error("Failed to fetch PAC file: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let pacScript = String(data: data, encoding: .utf8) else {
                Logger.error("Invalid PAC file data")
                return
            }
            
            Logger.log("PAC file loaded, size: \(pacScript.count) bytes")
            self?.configuration?.localPACScript = pacScript
        }.resume()
    }
    
    private func setupWPADDiscovery(domain: String) {
        WPADDiscovery.discoverWPAD(domain: domain) { [weak self] pacURLString in
            if let pacURLString = pacURLString {
                Logger.log("WPAD discovered: \(pacURLString)")
                self?.setupManualPAC(urlString: pacURLString)
            } else {
                Logger.error("WPAD discovery failed for domain: \(domain)")
            }
        }
    }
    
    private func setupLocalPAC(script: String) {
        Logger.log("Local PAC script loaded, size: \(script.count) bytes")
        configuration?.localPACScript = script
    }
    
    private func startProxyServer() {
        proxyServer = ProxyServer(port: localProxyPort)
        proxyServer?.pacEvaluator = { [weak self] urlString in
            return self?.evaluateProxy(for: urlString) ?? "DIRECT"
        }
        
        do {
            try proxyServer?.start()
            Logger.log("Proxy server started on port \(localProxyPort)")
        } catch {
            Logger.error("Failed to start proxy server: \(error.localizedDescription)")
        }
    }
    
    private func startPacketProcessing() {
        readPackets()
    }
    
    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            
            for packet in packets {
                self.processPacket(packet)
            }
            
            self.readPackets()
        }
    }
    
    private func processPacket(_ packet: Data) {
        guard packet.count >= 20 else { return }
        
        let version = (packet[0] & 0xF0) >> 4
        
        if version == 4 {
            processIPv4Packet(packet)
        } else if version == 6 {
            processIPv6Packet(packet)
        }
    }
    
    private func processIPv4Packet(_ packet: Data) {
        guard packet.count >= 20 else { return }
        
        let headerLength = Int((packet[0] & 0x0F) * 4)
        guard packet.count >= headerLength else { return }
        
        let protocol = packet[9]
        
        let sourceIP = "\(packet[12]).\(packet[13]).\(packet[14]).\(packet[15])"
        let destIP = "\(packet[16]).\(packet[17]).\(packet[18]).\(packet[19])"
        
        if protocol == 6 {
            processTCPPacket(packet, headerLength: headerLength, sourceIP: sourceIP, destIP: destIP)
        } else if protocol == 17 {
            processUDPPacket(packet, headerLength: headerLength, sourceIP: sourceIP, destIP: destIP)
        }
    }
    
    private func processIPv6Packet(_ packet: Data) {
    }
    
    private func processTCPPacket(_ packet: Data, headerLength: Int, sourceIP: String, destIP: String) {
        guard packet.count >= headerLength + 4 else { return }
        
        let sourcePort = UInt16(packet[headerLength]) << 8 | UInt16(packet[headerLength + 1])
        let destPort = UInt16(packet[headerLength + 2]) << 8 | UInt16(packet[headerLength + 3])
        
        if destPort == 80 || destPort == 443 {
            routeThroughProxy(packet, destIP: destIP, destPort: destPort)
        } else {
            packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
        }
    }
    
    private func processUDPPacket(_ packet: Data, headerLength: Int, sourceIP: String, destIP: String) {
        guard packet.count >= headerLength + 4 else { return }
        
        let destPort = UInt16(packet[headerLength + 2]) << 8 | UInt16(packet[headerLength + 3])
        
        if destPort == 53 {
            packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
        } else {
            routeThroughProxy(packet, destIP: destIP, destPort: destPort)
        }
    }
    
    private func routeThroughProxy(_ packet: Data, destIP: String, destPort: UInt16) {
        let url = destPort == 443 ? "https://\(destIP)" : "http://\(destIP)"
        let proxyString = evaluateProxy(for: url)
        
        if proxyString == "DIRECT" {
            packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
        } else {
            proxyServer?.forwardPacket(packet, to: destIP, port: destPort)
        }
    }
    
    private func evaluateProxy(for urlString: String) -> String {
        guard let pacScript = configuration?.localPACScript,
              let url = URL(string: urlString) else {
            return "DIRECT"
        }
        
        var result = "DIRECT"
        let semaphore = DispatchSemaphore(value: 0)
        
        PACEvaluator.evaluatePACScript(pacScript, targetURL: url) { proxyString in
            result = proxyString ?? "DIRECT"
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 1)
        
        return result
    }
}