import Foundation

struct ProxyConfiguration: Codable {
    var pacMode: PACMode
    var pacURL: String?
    var wpadDomain: String
    var localPACScript: String?
    var localProxyPort: Int
    var bypassLocalNetworks: Bool
    var enableLogging: Bool
    
    enum PACMode: String, Codable {
        case auto = "auto"
        case manual = "manual"
        case local = "local"
    }
    
    static var `default`: ProxyConfiguration {
        ProxyConfiguration(
            pacMode: .auto,
            pacURL: nil,
            wpadDomain: "sokolov.me",
            localPACScript: nil,
            localProxyPort: 8888,
            bypassLocalNetworks: true,
            enableLogging: true
        )
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.shared.set(data, forKey: "proxyConfiguration")
        }
    }
    
    static func load() -> ProxyConfiguration {
        guard let data = UserDefaults.shared.data(forKey: "proxyConfiguration"),
              let config = try? JSONDecoder().decode(ProxyConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
}

extension UserDefaults {
    static var shared: UserDefaults {
        return UserDefaults(suiteName: "group.me.sokolov.wpadproxy") ?? .standard
    }
}