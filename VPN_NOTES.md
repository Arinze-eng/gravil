# VPN Notes (Android)

## What was fixed
- VPN service now runs as a **foreground service** (required on modern Android), so it won't instantly die in the background.
- A persistent **VPN notification** is shown, and Android should display the **VPN key icon** while the service is running.
- SSH port forwarding is **dynamic SOCKS5** on `127.0.0.1:1080`.

## Tun2socks (now implemented)
This build integrates **HevSocks5Tunnel** (native `libhev-socks5-tunnel.so`) and starts it with the VPN TUN file descriptor.

Flow:
1. App starts SSH dynamic port forwarding (SOCKS5) on `127.0.0.1:1080`
2. VPN TUN interface is established (Android VpnService)
3. Native tun2socks bridges **TUN → SOCKS5**

If VPN permission is granted, you should now see:
- the Android **VPN key icon**
- a persistent notification “VPN connected”

## Notes
- If your SSH server / websocket proxy disconnects, the tunnel will also stop working.
- You may still need to exclude the VPN service’s own sockets using `VpnService.protect(...)` for production stability.
