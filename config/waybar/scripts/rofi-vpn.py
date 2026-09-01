#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import ipaddress

THEME = os.path.expanduser("~/.config/rofi/vpn-menu.rasi")

def get_netmask(prefixlen):
    try:
        return str(ipaddress.IPv4Network(f"0.0.0.0/{prefixlen}").netmask)
    except Exception:
        return ""

def is_vpn_interface(iface):
    name = iface.get("ifname", "")
    if name in ("lo", "docker0") or name.startswith(("enp", "eth", "wlan", "wlp", "vmnet", "vboxnet", "br-", "virbr", "docker")):
        return False
    vpn_prefixes = ("tun", "tap", "wg", "ppp", "fct", "fssl", "cscotun", "tailscale", "ipsec", "wireguard", "zt")
    for prefix in vpn_prefixes:
        if name.startswith(prefix):
            return True
    link_type = iface.get("link_type", "")
    if link_type in ("none", "wireguard", "ppp", "ipip", "gre"):
        return True
    return False

def get_vpn_data():
    try:
        addrs = json.loads(subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True, check=True).stdout)
    except Exception:
        addrs = []
    try:
        routes = json.loads(subprocess.run(["ip", "-j", "route"], capture_output=True, text=True, check=True).stdout)
    except Exception:
        routes = []

    vpns = []
    for iface in addrs:
        flags = iface.get("flags", [])
        if "UP" not in flags:
            continue
        if is_vpn_interface(iface):
            name = iface.get("ifname", "")
            
            # VPN Type
            vpn_type = "VPN"
            if name.startswith(("wg", "wireguard")):
                vpn_type = "WireGuard"
            elif name.startswith(("tun", "tap")):
                vpn_type = "OpenVPN/SSL"
            elif name.startswith(("ppp", "fct", "fssl")):
                vpn_type = "FortiClient/PPP"
            elif name.startswith("tailscale"):
                vpn_type = "Tailscale"
            elif name.startswith("cscotun"):
                vpn_type = "Cisco"
            elif name.startswith("zt"):
                vpn_type = "ZeroTier"

            # Gateway
            gateway = "Direct / P2P"
            for r in routes:
                if r.get("dev") == name and "gateway" in r:
                    gateway = r["gateway"]
                    break

            # Addresses
            ipv4_list = []
            for addr in iface.get("addr_info", []):
                if addr.get("family") == "inet":
                    ip = addr.get("local", "")
                    plen = addr.get("prefixlen")
                    mask = get_netmask(plen) if plen else ""
                    ipv4_list.append({"ip": ip, "prefixlen": plen, "netmask": mask})

            vpns.append({
                "ifname": name,
                "type": vpn_type,
                "gateway": gateway,
                "ips": ipv4_list
            })
    return vpns

def main():
    vpns = get_vpn_data()
    if not vpns:
        options = ["󰖂  No hay conexiones VPN activas"]
    else:
        options = []
        for v in vpns:
            options.append(f"󰖂  [ {v['ifname']} ]  -  Tipo: {v['type']}")
            if v["ips"]:
                for ip_info in v["ips"]:
                    options.append(f"   ├─ 󰩟 IP: {ip_info['ip']}")
                    options.append(f"   ├─ 󰩠 Máscara: {ip_info['netmask']} (/{ip_info['prefixlen']})")
            else:
                options.append("   ├─ 󰩟 IP: Sin IPv4")
                options.append("   ├─ 󰩠 Máscara: N/A")
            options.append(f"   └─ 󰌘 Gateway: {v['gateway']}")
            options.append("") # Separador

    rofi_input = "\n".join(options)
    rofi_cmd = ["rofi", "-dmenu", "-i", "-theme", THEME, "-p", "VPNs"]
    res = subprocess.run(rofi_cmd, input=rofi_input, text=True, capture_output=True)
    
    selected = res.stdout.strip()
    if not selected or "No hay conexiones" in selected:
        return

    # Si seleccionó una línea de IP o Gateway, copiarla al portapapeles
    if "IP:" in selected:
        val = selected.split("IP:")[-1].strip()
        subprocess.run(["wl-copy", val])
        subprocess.run(["notify-send", "VPN Copiado", f"IP {val} copiada al portapapeles"])
    elif "Gateway:" in selected:
        val = selected.split("Gateway:")[-1].strip()
        if val != "Direct / P2P":
            subprocess.run(["wl-copy", val])
            subprocess.run(["notify-send", "VPN Copiado", f"Gateway {val} copiado al portapapeles"])
    elif "Máscara:" in selected:
        val = selected.split("Máscara:")[-1].split("(")[0].strip()
        subprocess.run(["wl-copy", val])
        subprocess.run(["notify-send", "VPN Copiado", f"Máscara {val} copiada al portapapeles"])

if __name__ == "__main__":
    main()
