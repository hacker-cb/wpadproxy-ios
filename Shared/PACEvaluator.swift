import Foundation
import CFNetwork

class PACEvaluator {
    
    static func evaluatePAC(pacURL: URL, targetURL: String, completion: @escaping (String?) -> Void) {
        guard let targetURL = URL(string: targetURL) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: pacURL) { data, response, error in
            guard let data = data,
                  let pacScript = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            evaluatePACScript(pacScript, targetURL: targetURL, completion: completion)
        }.resume()
    }
    
    static func evaluatePACScript(_ pacScript: String, targetURL: URL, completion: @escaping (String?) -> Void) {
        var cfError: Unmanaged<CFError>?
        
        let proxies = CFNetworkExecuteProxyAutoConfigurationScript(
            pacScript as CFString,
            targetURL as CFURL,
            &cfError
        )?.takeRetainedValue() as? [[String: Any]]
        
        if let error = cfError {
            Logger.log("PAC evaluation error: \(error.takeRetainedValue())")
            completion(nil)
            return
        }
        
        guard let proxies = proxies, !proxies.isEmpty else {
            completion("DIRECT")
            return
        }
        
        let proxyStrings = proxies.compactMap { dict -> String? in
            if let type = dict[kCFProxyTypeKey as String] as? String {
                if type == kCFProxyTypeNone as String {
                    return "DIRECT"
                } else if type == kCFProxyTypeHTTP as String || type == kCFProxyTypeHTTPS as String {
                    let host = dict[kCFProxyHostNameKey as String] as? String ?? ""
                    let port = dict[kCFProxyPortNumberKey as String] as? Int ?? 0
                    return "PROXY \(host):\(port)"
                } else if type == kCFProxyTypeSOCKS as String {
                    let host = dict[kCFProxyHostNameKey as String] as? String ?? ""
                    let port = dict[kCFProxyPortNumberKey as String] as? Int ?? 0
                    return "SOCKS \(host):\(port)"
                }
            }
            return nil
        }
        
        completion(proxyStrings.first ?? "DIRECT")
    }
    
    static func evaluateWithSystemProxySettings(targetURL: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: targetURL),
              let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            completion(nil)
            return
        }
        
        let proxies = CFNetworkCopyProxiesForURL(url as CFURL, proxySettings).takeRetainedValue() as? [[String: Any]]
        
        guard let firstProxy = proxies?.first else {
            completion("DIRECT")
            return
        }
        
        if let type = firstProxy[kCFProxyTypeKey as String] as? String {
            if type == kCFProxyTypeNone as String {
                completion("DIRECT")
            } else if type == kCFProxyTypeHTTP as String || type == kCFProxyTypeHTTPS as String {
                let host = firstProxy[kCFProxyHostNameKey as String] as? String ?? ""
                let port = firstProxy[kCFProxyPortNumberKey as String] as? Int ?? 0
                completion("PROXY \(host):\(port)")
            } else if type == kCFProxyTypeAutoConfigurationURL as String {
                if let pacURL = firstProxy[kCFProxyAutoConfigurationURLKey as String] as? URL {
                    evaluatePAC(pacURL: pacURL, targetURL: targetURL, completion: completion)
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
}