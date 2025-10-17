# WPAD Proxy iOS App

## Project Overview
This is a complete iOS application source code that implements system-wide proxy configuration using PAC (Proxy Auto-Config) files and WPAD (Web Proxy Auto-Discovery) protocol. The app uses Apple's NetworkExtension framework to intercept and route all network traffic through configured proxy servers.

## Current State
- **Status**: Source code complete, ready for Xcode compilation
- **Platform**: iOS 14.0+ (requires macOS with Xcode to build)
- **Bundle ID**: me.sokolov.wpadproxy
- **Domain**: sokolov.me

## Architecture
- **Main App**: SwiftUI-based interface for configuration and monitoring
- **Packet Tunnel Extension**: NetworkExtension that handles system-wide traffic
- **Shared Components**: PAC evaluator, WPAD discovery, proxy configuration

## Key Features
- System-wide proxy enforcement via NEPacketTunnelProvider
- PAC file evaluation using native CFNetwork APIs  
- WPAD auto-discovery (DNS-based)
- Manual PAC URL configuration
- Local PAC script support
- Real-time proxy rule testing
- Connection logging and monitoring

## Build Requirements
- macOS with Xcode 15.0+
- Apple Developer Account ($99/year)
- Physical iOS device (no simulator support)
- NetworkExtension entitlements

## Files Structure
```
WPADProxy.xcodeproj/        # Xcode project file
WPADProxy/                  # Main app
  - WPADProxyApp.swift      # App entry point
  - ContentView.swift       # Main UI
  - Views/                  # UI components
  - Services/               # VPN manager
  - Info.plist              # App configuration
  - WPADProxy.entitlements  # App permissions
PacketTunnel/               # Network Extension
  - PacketTunnelProvider.swift  # Traffic interceptor
  - ProxyServer.swift           # Local proxy server
  - Info.plist                  # Extension configuration
  - PacketTunnel.entitlements   # Extension permissions
Shared/                     # Shared code
  - PACEvaluator.swift      # PAC script evaluation
  - ProxyConfiguration.swift # Configuration model
  - WPADDiscovery.swift     # WPAD auto-discovery
  - Logger.swift            # Logging utility
```

## Next Steps for User
1. Open WPADProxy.xcodeproj in Xcode on macOS
2. Configure development team in project settings
3. Build and run on physical iOS device
4. Set up WPAD server at wpad.sokolov.me
5. Configure PAC rules in the app

## Technical Notes
- Uses CFNetworkExecuteProxyAutoConfigurationScript for PAC evaluation
- Implements local proxy server using Network.framework
- Memory limit of 15MB for Network Extension
- Requires proper code signing and provisioning profiles

## User Preferences
- Domain: sokolov.me
- Default WPAD URL: http://wpad.sokolov.me/wpad.dat
- Local proxy port: 8888

## Recent Changes
- October 2024: Initial implementation completed
- All source files created with proper Swift syntax
- Configuration files set up for Xcode compilation
- Documentation and examples provided