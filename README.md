# WPAD Proxy for iOS

A system-wide proxy application for iOS that uses PAC (Proxy Auto-Config) files and WPAD (Web Proxy Auto-Discovery) to automatically configure proxy settings for all network connections.

## Features

- ✅ System-wide proxy enforcement via NetworkExtension
- ✅ PAC file evaluation using native CFNetwork APIs
- ✅ WPAD auto-discovery support
- ✅ Manual PAC URL configuration
- ✅ Local PAC script support
- ✅ Real-time proxy rule testing
- ✅ Connection logging and monitoring
- ✅ Support for HTTP, HTTPS, and SOCKS proxies
- ✅ Automatic bypass for local networks

## Requirements

- **macOS** with Xcode 15.0 or later
- **iOS 14.0+** deployment target
- **Apple Developer Account** ($99/year) for NetworkExtension entitlements
- **Physical iOS device** (NetworkExtension doesn't work in simulators)

## Setup Instructions

### 1. Open the Project

1. Double-click `WPADProxy.xcodeproj` to open in Xcode
2. Wait for Xcode to index the project

### 2. Configure Your Development Team

1. Select the **WPADProxy** target in Xcode
2. Go to **Signing & Capabilities** tab
3. Select your development team
4. Xcode will automatically create provisioning profiles

### 3. Configure App Groups

1. In **Signing & Capabilities**, find **App Groups**
2. If not present, click **+ Capability** → **App Groups**
3. Ensure `group.me.sokolov.wpadproxy` is checked
4. Repeat for the **PacketTunnel** target

### 4. Configure Network Extension

1. Go to your Apple Developer account at https://developer.apple.com
2. Navigate to **Certificates, Identifiers & Profiles**
3. Find your app identifier: `me.sokolov.wpadproxy`
4. Edit the identifier and enable **Network Extensions**
5. Select **Packet Tunnel Provider**
6. Save changes

### 5. Update Bundle Identifiers (if needed)

If you want to use your own bundle ID:

1. Replace `me.sokolov.wpadproxy` with your bundle ID throughout the project
2. Update the App Group to `group.your.bundle.id`
3. Update both Info.plist files
4. Update entitlements files

### 6. Build and Run

1. Connect your iPhone/iPad via USB
2. Select your device from the device selector
3. Press **Cmd+R** to build and run
4. Trust the developer certificate on your device:
   - Go to **Settings** → **General** → **VPN & Device Management**
   - Find your developer profile and trust it

## First Run Configuration

### Enable the VPN Configuration

1. Launch the app on your device
2. Tap **Connect** to create the VPN configuration
3. iOS will prompt to add VPN configuration - tap **Allow**
4. Enter your device passcode
5. The VPN will now appear in Settings → VPN

### Configure Your PAC Settings

#### Option 1: Auto-Discovery (WPAD)
1. Go to **Configuration** tab
2. Select **Auto-Discovery (WPAD)**
3. Enter your domain (default: sokolov.me)
4. The app will look for `wpad.sokolov.me/wpad.dat`

#### Option 2: Manual PAC URL
1. Select **Manual PAC URL**
2. Enter your PAC file URL
3. Tap **Test PAC URL** to verify

#### Option 3: Local Rules
1. Select **Local Rules**
2. Tap **Edit PAC Script**
3. Enter your PAC JavaScript or use the template

## Testing Your Configuration

1. Go to the **Test Rules** tab
2. Enter a URL (e.g., https://google.com)
3. Tap **Test** to see which proxy will be used
4. Results show either:
   - `PROXY hostname:port` - Traffic goes through proxy
   - `DIRECT` - Traffic bypasses proxy

## Your WPAD Setup

Since your domain is `sokolov.me`, ensure:

1. Your PAC file is accessible at: `http://wpad.sokolov.me/wpad.dat`
2. DNS record exists: `wpad.sokolov.me` → your server IP
3. Web server returns correct MIME type: `application/x-ns-proxy-autoconfig`

## Example PAC File

Here's a sample PAC file for your domain:

```javascript
function FindProxyForURL(url, host) {
    // Direct connection for local addresses
    if (isPlainHostName(host) ||
        shExpMatch(host, "*.local") ||
        isInNet(host, "10.0.0.0", "255.0.0.0") ||
        isInNet(host, "172.16.0.0", "255.240.0.0") ||
        isInNet(host, "192.168.0.0", "255.255.0.0") ||
        dnsDomainIs(host, ".sokolov.me")) {
        return "DIRECT";
    }
    
    // Use proxy for specific domains
    if (dnsDomainIs(host, ".facebook.com") ||
        dnsDomainIs(host, ".twitter.com")) {
        return "PROXY proxy1.sokolov.me:8080";
    }
    
    // Default: try proxy first, then direct
    return "PROXY proxy.sokolov.me:8080; DIRECT";
}
```

## Troubleshooting

### VPN Won't Connect
- Ensure NetworkExtension capability is enabled
- Check that provisioning profiles are valid
- Verify bundle IDs match in all targets
- Make sure you're testing on a physical device

### PAC File Not Loading
- Check PAC file URL is accessible
- Verify MIME type is correct
- Test PAC syntax using the app's test feature
- Check console logs in Xcode

### Proxy Not Working
- Verify PAC script returns valid proxy strings
- Check proxy server is running and accessible
- Review connection logs in the Status tab
- Ensure iOS device can reach the proxy server

### Memory Issues
NetworkExtensions have a 15MB memory limit. If the extension crashes:
- Reduce logging
- Optimize PAC evaluation caching
- Minimize stored connection data

## Console Logging

To view detailed logs while debugging:

1. Run the app from Xcode
2. Open **Console.app** on your Mac
3. Filter by your device name
4. Search for "me.sokolov.wpadproxy"

## Security Notes

- PAC scripts run in a sandboxed JavaScript environment
- Network traffic is processed locally on device
- No data is sent to external servers unless configured
- Proxy credentials should be handled securely

## Support

For issues specific to this implementation:
- Check the logs in Xcode Console
- Review the Status tab for connection errors
- Verify your PAC file syntax
- Test with a simple PAC file first

## License

This project is provided as-is for your use with your domain sokolov.me.