const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs').promises;
const path = require('path');
const { createPacResolver } = require('pac-resolver');
const fetch = require('node-fetch');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.text({ type: 'application/x-ns-proxy-autoconfig' }));

app.use(express.static('public'));

let currentPACScript = `
function FindProxyForURL(url, host) {
    // Direct connection for local addresses
    if (isPlainHostName(host) ||
        shExpMatch(host, "*.local") ||
        isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        isInNet(dnsResolve(host), "172.16.0.0", "255.240.0.0") ||
        isInNet(dnsResolve(host), "192.168.0.0", "255.255.0.0") ||
        isInNet(dnsResolve(host), "127.0.0.0", "255.0.0.0")) {
        return "DIRECT";
    }
    
    // Use proxy for all other traffic
    return "PROXY proxy.example.com:8080; DIRECT";
}`;

let wpadConfig = {
    enabled: true,
    domain: 'example.com',
    autoDiscoveryMode: 'manual',
    pacUrl: '',
    localScript: currentPACScript
};

// Save configuration to file
const saveConfig = async () => {
    try {
        await fs.writeFile('wpad-config.json', JSON.stringify({ wpadConfig, currentPACScript }, null, 2));
    } catch (error) {
        console.error('Error saving config:', error);
    }
};

// Load configuration from file
const loadConfig = async () => {
    try {
        const data = await fs.readFile('wpad-config.json', 'utf8');
        const config = JSON.parse(data);
        if (config.wpadConfig) wpadConfig = config.wpadConfig;
        if (config.currentPACScript) currentPACScript = config.currentPACScript;
    } catch (error) {
        console.log('No existing config found, using defaults');
    }
};

// Serve WPAD file
app.get('/wpad.dat', (req, res) => {
    res.setHeader('Content-Type', 'application/x-ns-proxy-autoconfig');
    res.send(currentPACScript);
});

// Serve PAC file
app.get('/proxy.pac', (req, res) => {
    res.setHeader('Content-Type', 'application/x-ns-proxy-autoconfig');
    res.send(currentPACScript);
});

// Get current configuration
app.get('/api/config', (req, res) => {
    res.json({ wpadConfig, currentPACScript });
});

// Update configuration
app.post('/api/config', async (req, res) => {
    const { config, pacScript } = req.body;
    if (config) wpadConfig = { ...wpadConfig, ...config };
    if (pacScript !== undefined) currentPACScript = pacScript;
    await saveConfig();
    res.json({ success: true, wpadConfig, currentPACScript });
});

// Validate PAC script
app.post('/api/validate-pac', async (req, res) => {
    const { script } = req.body;
    
    try {
        const resolver = createPacResolver(script);
        const testUrl = 'https://example.com';
        const result = await resolver(testUrl);
        
        res.json({
            valid: true,
            message: 'PAC script is valid',
            testResult: {
                url: testUrl,
                result: result
            }
        });
    } catch (error) {
        res.json({
            valid: false,
            message: 'PAC script validation failed',
            error: error.message
        });
    }
});

// Test URL with current PAC script
app.post('/api/test-url', async (req, res) => {
    const { url } = req.body;
    
    try {
        const resolver = createPacResolver(currentPACScript);
        const result = await resolver(url);
        
        let proxyInfo = {
            url,
            result,
            description: ''
        };
        
        if (result === 'DIRECT') {
            proxyInfo.description = 'Direct connection (no proxy)';
        } else if (result.startsWith('PROXY ')) {
            const proxy = result.substring(6);
            proxyInfo.description = `Proxy server: ${proxy}`;
        } else if (result.startsWith('SOCKS ')) {
            const socks = result.substring(6);
            proxyInfo.description = `SOCKS proxy: ${socks}`;
        }
        
        res.json({
            success: true,
            proxyInfo
        });
    } catch (error) {
        res.json({
            success: false,
            error: error.message
        });
    }
});

// Fetch remote PAC file
app.post('/api/fetch-pac', async (req, res) => {
    const { url } = req.body;
    
    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const script = await response.text();
        
        // Validate the fetched script
        try {
            const resolver = createPacResolver(script);
            await resolver('https://example.com');
            
            res.json({
                success: true,
                script
            });
        } catch (validationError) {
            res.json({
                success: false,
                error: `Invalid PAC script: ${validationError.message}`
            });
        }
    } catch (error) {
        res.json({
            success: false,
            error: error.message
        });
    }
});

// Get PAC script templates
app.get('/api/templates', (req, res) => {
    const templates = [
        {
            name: 'Basic Proxy',
            description: 'Simple proxy configuration with local network bypass',
            script: `function FindProxyForURL(url, host) {
    // Direct for local networks
    if (isInNet(dnsResolve(host), "192.168.0.0", "255.255.0.0") ||
        isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        isInNet(dnsResolve(host), "172.16.0.0", "255.240.0.0")) {
        return "DIRECT";
    }
    return "PROXY proxy.example.com:8080";
}`
        },
        {
            name: 'Domain-based Routing',
            description: 'Route specific domains through proxy',
            script: `function FindProxyForURL(url, host) {
    // Proxy for specific domains
    if (dnsDomainIs(host, ".facebook.com") ||
        dnsDomainIs(host, ".twitter.com") ||
        dnsDomainIs(host, ".youtube.com")) {
        return "PROXY proxy.example.com:8080";
    }
    return "DIRECT";
}`
        },
        {
            name: 'Corporate Network',
            description: 'Corporate proxy with exceptions',
            script: `function FindProxyForURL(url, host) {
    // Direct for internal corporate domains
    if (dnsDomainIs(host, ".internal.company.com") ||
        dnsDomainIs(host, ".corp.company.com")) {
        return "DIRECT";
    }
    
    // Direct for local networks
    if (isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0")) {
        return "DIRECT";
    }
    
    // Everything else through corporate proxy
    return "PROXY proxy.company.com:3128";
}`
        },
        {
            name: 'Load Balancing',
            description: 'Multiple proxies with failover',
            script: `function FindProxyForURL(url, host) {
    // Round-robin between proxies
    var proxies = [
        "PROXY proxy1.example.com:8080",
        "PROXY proxy2.example.com:8080",
        "PROXY proxy3.example.com:8080"
    ];
    
    // Simple hash based on hostname
    var hash = 0;
    for (var i = 0; i < host.length; i++) {
        hash = ((hash << 5) - hash) + host.charCodeAt(i);
        hash = hash & hash;
    }
    
    var index = Math.abs(hash) % proxies.length;
    return proxies[index] + "; DIRECT";
}`
        }
    ];
    
    res.json(templates);
});

// Health check
app.get('/api/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Start server
loadConfig().then(() => {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`WPAD Proxy Manager server running on http://0.0.0.0:${PORT}`);
        console.log(`WPAD file available at http://0.0.0.0:${PORT}/wpad.dat`);
        console.log(`PAC file available at http://0.0.0.0:${PORT}/proxy.pac`);
    });
});