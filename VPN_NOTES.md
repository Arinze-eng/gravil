# VPN Notes (Android)

## What was fixed
- VPN service now runs as a **foreground service** (required on modern Android), so it won't instantly die in the background.
- A persistent **VPN notification** is shown, and Android should display the **VPN key icon** while the service is running.
- SSH port forwarding was corrected to **dynamic SOCKS5** (`setPortForwardingD(1080)`).

## Important limitation
Right now, the VPN service **creates a TUN interface** and **opens an SSH SOCKS5 proxy**, but it does **NOT yet route all device traffic** through the SOCKS proxy.

To truly tunnel traffic, you must connect the TUN fd to the SOCKS proxy using a **tun2socks** implementation (native binary or library).

If you want, I can integrate a tun2socks solution next (requires adding a native dependency and wiring the TUN fd to it).
