import Foundation
import Network

class ProxyServer {
    private let port: UInt16
    private var listener: NWListener?
    private var connections: Set<ProxyConnection> = []
    private let queue = DispatchQueue(label: "me.sokolov.wpadproxy.proxyserver")
    
    var pacEvaluator: ((String) -> String)?
    var currentProxy: String = "DIRECT"
    
    init(port: UInt16) {
        self.port = port
    }
    
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener?.start(queue: queue)
        Logger.log("Proxy server listening on port \(port)")
    }
    
    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        Logger.log("Proxy server stopped")
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        let proxyConnection = ProxyConnection(connection: connection, pacEvaluator: pacEvaluator)
        connections.insert(proxyConnection)
        
        proxyConnection.onComplete = { [weak self] in
            self?.connections.remove(proxyConnection)
        }
        
        proxyConnection.start()
    }
    
    func forwardPacket(_ packet: Data, to destIP: String, port: UInt16) {
    }
}

class ProxyConnection: Hashable {
    private let connection: NWConnection
    private var remoteConnection: NWConnection?
    private let pacEvaluator: ((String) -> String)?
    private let queue = DispatchQueue(label: "me.sokolov.wpadproxy.proxyconnection")
    
    var onComplete: (() -> Void)?
    
    init(connection: NWConnection, pacEvaluator: ((String) -> String)?) {
        self.connection = connection
        self.pacEvaluator = pacEvaluator
    }
    
    func start() {
        connection.start(queue: queue)
        receiveHTTPRequest()
    }
    
    func cancel() {
        connection.cancel()
        remoteConnection?.cancel()
    }
    
    private func receiveHTTPRequest() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.error("Connection error: \(error.localizedDescription)")
                self.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.handleHTTPData(data)
            }
            
            if !isComplete {
                self.receiveHTTPRequest()
            } else {
                self.onComplete?()
            }
        }
    }
    
    private func handleHTTPData(_ data: Data) {
        guard let request = String(data: data, encoding: .utf8) else { return }
        
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        
        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 3 else { return }
        
        let method = components[0]
        let urlString = components[1]
        
        if method == "CONNECT" {
            handleCONNECT(urlString: urlString, requestData: data)
        } else {
            handleHTTPRequest(urlString: urlString, requestData: data)
        }
    }
    
    private func handleCONNECT(urlString: String, requestData: Data) {
        let components = urlString.components(separatedBy: ":")
        guard components.count == 2,
              let port = UInt16(components[1]) else {
            sendError()
            return
        }
        
        let host = components[0]
        let targetURL = "https://\(host):\(port)"
        
        let proxyString = pacEvaluator?(targetURL) ?? "DIRECT"
        
        if proxyString == "DIRECT" {
            connectDirectly(to: host, port: port, isHTTPS: true)
        } else if let proxyEndpoint = parseProxy(proxyString) {
            connectViaProxy(to: host, port: port, proxy: proxyEndpoint, isHTTPS: true)
        } else {
            sendError()
        }
    }
    
    private func handleHTTPRequest(urlString: String, requestData: Data) {
        guard let url = URL(string: urlString),
              let host = url.host else {
            sendError()
            return
        }
        
        let port = UInt16(url.port ?? 80)
        let proxyString = pacEvaluator?(urlString) ?? "DIRECT"
        
        if proxyString == "DIRECT" {
            connectDirectly(to: host, port: port, isHTTPS: false)
        } else if let proxyEndpoint = parseProxy(proxyString) {
            connectViaProxy(to: host, port: port, proxy: proxyEndpoint, isHTTPS: false)
        } else {
            sendError()
        }
    }
    
    private func connectDirectly(to host: String, port: UInt16, isHTTPS: Bool) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        remoteConnection = NWConnection(to: endpoint, using: .tcp)
        
        remoteConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if isHTTPS {
                    self?.send200OK()
                }
                self?.startForwarding()
            case .failed(let error):
                Logger.error("Remote connection failed: \(error.localizedDescription)")
                self?.sendError()
            default:
                break
            }
        }
        
        remoteConnection?.start(queue: queue)
    }
    
    private func connectViaProxy(to host: String, port: UInt16, proxy: NWEndpoint, isHTTPS: Bool) {
        remoteConnection = NWConnection(to: proxy, using: .tcp)
        
        remoteConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if isHTTPS {
                    let connectRequest = "CONNECT \(host):\(port) HTTP/1.1\r\nHost: \(host)\r\n\r\n"
                    self?.remoteConnection?.send(content: connectRequest.data(using: .utf8), completion: .contentProcessed { _ in
                        self?.waitForProxyResponse()
                    })
                } else {
                    self?.startForwarding()
                }
            case .failed(let error):
                Logger.error("Proxy connection failed: \(error.localizedDescription)")
                self?.sendError()
            default:
                break
            }
        }
        
        remoteConnection?.start(queue: queue)
    }
    
    private func waitForProxyResponse() {
        remoteConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let data = data,
               let response = String(data: data, encoding: .utf8),
               response.contains("200") {
                self?.send200OK()
                self?.startForwarding()
            } else {
                self?.sendError()
            }
        }
    }
    
    private func send200OK() {
        let response = "HTTP/1.1 200 Connection Established\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
    }
    
    private func sendError() {
        let response = "HTTP/1.1 502 Bad Gateway\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            self.cancel()
        })
    }
    
    private func startForwarding() {
        forwardData(from: connection, to: remoteConnection)
        forwardData(from: remoteConnection, to: connection)
    }
    
    private func forwardData(from source: NWConnection?, to destination: NWConnection?) {
        source?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                destination?.send(content: data, completion: .contentProcessed { _ in
                    if !isComplete {
                        self?.forwardData(from: source, to: destination)
                    }
                })
            } else if isComplete || error != nil {
                self?.cancel()
            }
        }
    }
    
    private func parseProxy(_ proxyString: String) -> NWEndpoint? {
        let components = proxyString.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }
        
        let proxyPart = components[1]
        let hostPort = proxyPart.components(separatedBy: ":")
        guard hostPort.count == 2,
              let port = UInt16(hostPort[1]) else { return nil }
        
        return NWEndpoint.hostPort(
            host: NWEndpoint.Host(hostPort[0]),
            port: NWEndpoint.Port(integerLiteral: port)
        )
    }
    
    static func == (lhs: ProxyConnection, rhs: ProxyConnection) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}