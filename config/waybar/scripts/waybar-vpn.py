#!/usr/bin/env python3
import json
import os
import subprocess
import sys

def is_zerotier(ifname):
    # ZeroTier interfaces start with 'zt' or 'ztu'
    if ifname.startswith("zt"):
        return True
    return False

def get_ip_links():
    try:
        res = subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True, check=True)
        return json.loads(res.stdout)
    except Exception:
        return []

def is_vpn_interface(iface):
    name = iface.get("ifname", "")
    
    # Exclude loopback, physical Ethernet/Wifi and VM interfaces
    if name in ("lo", "docker0") or name.startswith(("enp", "eth", "wlan", "wlp", "vmnet", "vboxnet", "br-", "virbr", "docker")):
        return False
    
    # Exclude ZeroTier
    if is_zerotier(name):
        return False
    
    # Common VPN interface prefixes
    # tun* (OpenVPN, FortiClient SSL-VPN, etc.)
    # tap* (OpenVPN TAP, etc.)
    # wg* or wireguard (WireGuard)
    # ppp* (FortiClient PPP, PPTP, L2TP)
    # fct* or fsslvpn* (FortiClient)
    # ciscotun*, tailscale*, ipsec*
    vpn_prefixes = ("tun", "tap", "wg", "ppp", "fct", "fssl", "cscotun", "tailscale", "ipsec", "wireguard")
    for prefix in vpn_prefixes:
        if name.startswith(prefix):
            return True
            
    # Check link_type if available
    link_type = iface.get("link_type", "")
    if link_type in ("none", "wireguard", "ppp", "ipip", "gre"):
        return True

    return False

def get_vpn_info(iface):
    name = iface.get("ifname", "")
    ipv4 = []
    ipv6 = []
    
    for addr in iface.get("addr_info", []):
        ip = addr.get("local")
        prefix = addr.get("prefixlen")
        family = addr.get("family")
        scope = addr.get("scope")
        
        if scope == "global" or scope == "host":
            if family == "inet" and ip:
                ipv4.append(f"{ip}/{prefix}" if prefix else ip)
            elif family == "inet6" and ip:
                ipv6.append(f"{ip}/{prefix}" if prefix else ip)
                
    # Detect VPN type label
    vpn_type = "VPN"
    if name.startswith("wg") or name.startswith("wireguard"):
        vpn_type = "WireGuard"
    elif name.startswith("tun") or name.startswith("tap"):
        vpn_type = "OpenVPN/SSL"
    elif name.startswith("ppp") or name.startswith("fct") or name.startswith("fssl"):
        vpn_type = "FortiClient/PPP"
    elif name.startswith("tailscale"):
        vpn_type = "Tailscale"
    elif name.startswith("cscotun"):
        vpn_type = "Cisco"
        
    return {
        "ifname": name,
        "type": vpn_type,
        "ipv4": ipv4,
        "ipv6": ipv6,
        "primary_ip": ipv4[0].split("/")[0] if ipv4 else (ipv6[0].split("/")[0] if ipv6 else "")
    }

def main():
    links = get_ip_links()
    active_vpns = []
    
    for link in links:
        flags = link.get("flags", [])
        if "UP" not in flags:
            continue
        if is_vpn_interface(link):
            vpn_data = get_vpn_info(link)
            active_vpns.append(vpn_data)

    if not active_vpns:
        # Hide widget when no VPN is connected
        print(json.dumps({"text": "", "alt": "disconnected", "tooltip": "", "class": "disconnected"}))
        return

    if len(active_vpns) == 1:
        v = active_vpns[0]
        display_ip = f" {v['primary_ip']}" if v['primary_ip'] else ""
        text = f"󰖂  {v['ifname']}{display_ip}"
    else:
        names = ", ".join([v["ifname"] for v in active_vpns])
        text = f"󰖂  {len(active_vpns)} VPNs ({names})"

    tooltip_lines = [f"<b>Conexiones VPN activas ({len(active_vpns)}):</b>"]
    for v in active_vpns:
        ip_str = ", ".join(v["ipv4"]) if v["ipv4"] else ("Sin IPv4" if not v["ipv6"] else ", ".join(v["ipv6"]))
        tooltip_lines.append(f"• <b>{v['ifname']}</b> ({v['type']}): {ip_str}")

    tooltip = "\n".join(tooltip_lines)

    output = {
        "text": text,
        "alt": "connected",
        "tooltip": tooltip,
        "class": "connected"
    }
    print(json.dumps(output))

if __name__ == "__main__":
    main()
