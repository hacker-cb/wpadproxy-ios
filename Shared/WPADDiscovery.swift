import Foundation

class WPADDiscovery {
    
    static func discoverWPAD(domain: String, completion: @escaping (String?) -> Void) {
        let wpadURL = "http://wpad.\(domain)/wpad.dat"
        
        testWPADURL(wpadURL) { success in
            if success {
                completion(wpadURL)
            } else {
                discoverViaDHCP { dhcpURL in
                    if let dhcpURL = dhcpURL {
                        completion(dhcpURL)
                    } else {
                        discoverViaDNS(domain: domain, completion: completion)
                    }
                }
            }
        }
    }
    
    private static func testWPADURL(_ urlString: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                Logger.log("WPAD found at: \(urlString)")
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    private static func discoverViaDHCP(completion: @escaping (String?) -> Void) {
        completion(nil)
    }
    
    private static func discoverViaDNS(domain: String, completion: @escaping (String?) -> Void) {
        let subdomains = domain.components(separatedBy: ".")
        var testDomains: [String] = []
        
        for i in 0..<subdomains.count {
            let subdomain = subdomains.dropFirst(i).joined(separator: ".")
            testDomains.append("http://wpad.\(subdomain)/wpad.dat")
        }
        
        discoverFromList(testDomains, index: 0, completion: completion)
    }
    
    private static func discoverFromList(_ urls: [String], index: Int, completion: @escaping (String?) -> Void) {
        guard index < urls.count else {
            completion(nil)
            return
        }
        
        testWPADURL(urls[index]) { success in
            if success {
                completion(urls[index])
            } else {
                discoverFromList(urls, index: index + 1, completion: completion)
            }
        }
    }
}