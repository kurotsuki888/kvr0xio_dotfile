#!/usr/bin/env python3
import sys
import os
import json
import glob
import subprocess
import threading
import time
import ipaddress
import tempfile
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Pango

CONFIG_DIR = os.path.expanduser("~/.config/vpnmenu")
CUSTOM_VPNS_FILE = os.path.join(CONFIG_DIR, "custom_vpns.json")
CREDENTIALS_FILE = os.path.join(CONFIG_DIR, "credentials.json")
os.makedirs(CONFIG_DIR, exist_ok=True)

IS_ROOT = (os.geteuid() == 0)

def wrap_root_cmd(cmd_list):
    """If running as root, execute directly; otherwise use pkexec."""
    if IS_ROOT:
        return cmd_list
    return ["pkexec"] + cmd_list

# Default FortiClient config for the user
FORTICLIENT_DEFAULT = {
    "id": "forticlient_openfortivpn",
    "name": "FortiClient (SC2 Monitoreo)",
    "type": "FortiClient SSL-VPN",
    "subtype": "openfortivpn",
    "host": "158.251.3.2:50443",
    "username": "monitoreoSC2.lorenzo",
    "trusted_cert": "69fb7b8d4d3beb137abf3b339a3e14ec68831d0f718704b3709c1afd7d8d0298",
    "active": False
}

def get_saved_credentials():
    if not os.path.exists(CREDENTIALS_FILE):
        return {}
    try:
        with open(CREDENTIALS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def save_credential(vpn_id, username, password):
    creds = get_saved_credentials()
    creds[vpn_id] = {"username": username, "password": password}
    try:
        with open(CREDENTIALS_FILE, "w") as f:
            json.dump(creds, f, indent=2)
        os.chmod(CREDENTIALS_FILE, 0o600)
    except Exception as e:
        print(f"Error saving creds: {e}")

def get_netmask(prefixlen):
    try:
        return str(ipaddress.IPv4Network(f"0.0.0.0/{prefixlen}").netmask)
    except Exception:
        return ""

def get_active_interfaces():
    try:
        res = subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True, check=True)
        links = json.loads(res.stdout)
    except Exception:
        links = []
    
    try:
        r_res = subprocess.run(["ip", "-j", "route"], capture_output=True, text=True, check=True)
        routes = json.loads(r_res.stdout)
    except Exception:
        routes = []

    active_map = {} # ifname -> {type, ips, gateway}
    for link in links:
        flags = link.get("flags", [])
        if "UP" not in flags:
            continue
        name = link.get("ifname", "")
        if name in ("lo", "docker0") or name.startswith(("enp", "eth", "wlan", "wlp", "vmnet", "vboxnet", "br-", "virbr", "docker", "veth")):
            continue
        
        vpn_prefixes = ("tun", "tap", "wg", "ppp", "fct", "fssl", "cscotun", "tailscale", "ipsec", "wireguard", "zt")
        link_type = link.get("link_type", "")
        is_vpn = any(name.startswith(p) for p in vpn_prefixes) or link_type in ("none", "wireguard", "ppp", "ipip", "gre")
        if not is_vpn:
            continue

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

        gateway = "Direct / P2P"
        for r in routes:
            if r.get("dev") == name and "gateway" in r:
                gateway = r["gateway"]
                break

        ipv4_list = []
        for addr in link.get("addr_info", []):
            if addr.get("family") == "inet":
                ip = addr.get("local", "")
                plen = addr.get("prefixlen")
                mask = get_netmask(plen) if plen else ""
                ipv4_list.append({"ip": ip, "prefixlen": plen, "netmask": mask})

        active_map[name] = {
            "ifname": name,
            "type": vpn_type,
            "gateway": gateway,
            "ips": ipv4_list
        }
    return active_map

def get_running_processes_info():
    """Returns running vpn process details."""
    running = {"openvpn": [], "openfortivpn": False, "wireguard": []}
    
    try:
        res = subprocess.run(["ps", "-eo", "pid,cmd"], capture_output=True, text=True)
        for line in res.stdout.strip().split("\n"):
            if "openvpn" in line and "--config" in line:
                running["openvpn"].append(line)
            if "openfortivpn" in line and not "grep" in line:
                running["openfortivpn"] = True
    except Exception:
        pass

    try:
        wg_show = subprocess.run(["wg", "show", "interfaces"], capture_output=True, text=True)
        if wg_show.returncode == 0:
            running["wireguard"] = wg_show.stdout.strip().split()
    except Exception:
        pass

    return running

def check_ovpn_needs_credentials(path):
    """Checks if .ovpn requires auth-user-pass or encrypted private key without embedded pass."""
    needs_userpass = False
    needs_keypass = False
    try:
        with open(path, "r", errors="ignore") as f:
            content = f.read()
            if "auth-user-pass" in content:
                # check if it already points to a credentials file
                lines = content.splitlines()
                for l in lines:
                    s = l.strip()
                    if s.startswith("auth-user-pass") and len(s.split()) == 1:
                        needs_userpass = True
            if "BEGIN ENCRYPTED PRIVATE KEY" in content:
                needs_keypass = True
    except Exception:
        pass
    return needs_userpass, needs_keypass

def get_openvpn_configs(running_info):
    search_dirs = [
        "/etc/openvpn",
        "/etc/openvpn/client",
        os.path.expanduser("~"),
        os.path.expanduser("~/work_sc2"),
        os.path.expanduser("~/pt"),
        os.path.expanduser("~/vpn"),
        os.path.expanduser("~/vpns"),
        os.path.expanduser("~/.config/openvpn")
    ]
    found_files = []
    for s_dir in search_dirs:
        if os.path.exists(s_dir):
            for f in glob.glob(os.path.join(s_dir, "*.ovpn")):
                if f not in found_files and os.path.isfile(f):
                    found_files.append(f)

    ovpns = []
    for path in found_files:
        name = os.path.basename(path)
        is_active = any(name in cmd for cmd in running_info["openvpn"])
        needs_userpass, needs_keypass = check_ovpn_needs_credentials(path)
        ovpns.append({
            "id": f"ovpn_{name}",
            "name": f"OpenVPN: {name}",
            "type": "OpenVPN",
            "subtype": "openvpn",
            "path": path,
            "active": is_active,
            "needs_userpass": needs_userpass,
            "needs_keypass": needs_keypass
        })
    return ovpns

def get_zerotier_entries(active_interfaces):
    zt_list = []
    for ifname in active_interfaces.keys():
        if ifname.startswith("zt"):
            zt_list.append({
                "id": f"zt_{ifname}",
                "name": f"ZeroTier ({ifname})",
                "type": "ZeroTier",
                "subtype": "zerotier",
                "ifname": ifname,
                "active": True
            })
            
    if not any(z["ifname"] == "ztu7tpupze" for z in zt_list):
        zt_list.append({
            "id": "zt_ztu7tpupze",
            "name": "ZeroTier (ztu7tpupze)",
            "type": "ZeroTier",
            "subtype": "zerotier",
            "ifname": "ztu7tpupze",
            "active": False
        })
    return zt_list

def get_wireguard_interfaces(running_info):
    wg_files = glob.glob("/etc/wireguard/*.conf") + glob.glob(os.path.expanduser("~/.config/wireguard/*.conf"))
    for root, dirs, files in os.walk(os.path.expanduser("~")):
        if ".local" in root or ".cache" in root or ".var" in root:
            continue
        for f in files:
            if f.endswith(".conf") and ("/pt/" in root or "/wireguard" in root or "wg" in f.lower()):
                p = os.path.join(root, f)
                if p not in wg_files:
                    wg_files.append(p)
    
    wg_vpns = []
    active_wg = running_info.get("wireguard", [])

    for path in set(wg_files):
        if not os.path.exists(path):
            continue
        basename = os.path.basename(path)
        ifname = os.path.splitext(basename)[0]
        
        is_wg = False
        try:
            with open(path, "r", errors="ignore") as f:
                content = f.read(400)
                if "[Interface]" in content or "[Peer]" in content:
                    is_wg = True
        except Exception:
            pass
        
        if is_wg or path.startswith("/etc/wireguard"):
            is_active = (ifname in active_wg)
            wg_vpns.append({
                "id": f"wg_{ifname}",
                "name": f"WireGuard: {ifname}",
                "type": "WireGuard",
                "subtype": "wireguard",
                "path": path,
                "ifname": ifname,
                "active": is_active
            })

    # Always ensure wg0_siem_sc2 is available even if conf file is in /etc/wireguard
    if not any(w.get("ifname") == "wg0_siem_sc2" for w in wg_vpns):
        is_active = ("wg0_siem_sc2" in active_wg)
        wg_vpns.append({
            "id": "wg_wg0_siem_sc2",
            "name": "WireGuard: wg0_siem_sc2",
            "type": "WireGuard",
            "subtype": "wireguard",
            "path": "/etc/wireguard/wg0_siem_sc2.conf",
            "ifname": "wg0_siem_sc2",
            "active": is_active
        })

    return wg_vpns

def get_custom_vpns():
    if not os.path.exists(CUSTOM_VPNS_FILE):
        return []
    try:
        with open(CUSTOM_VPNS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_custom_vpns(vpns):
    try:
        with open(CUSTOM_VPNS_FILE, "w") as f:
            json.dump(vpns, f, indent=2)
    except Exception as e:
        print(f"Error saving custom vpns: {e}")


# Credentials Dialog (Supports Username/Password and Remember checkbox)
class CredentialsDialog(Gtk.Dialog):
    def __init__(self, parent, vpn_name, default_user="", need_username=True, title="Credenciales Requeridas"):
        super().__init__(title=title, transient_for=parent, flags=0)
        self.set_default_size(360, 240)
        self.set_position(Gtk.WindowPosition.CENTER_ON_PARENT)
        self.need_username = need_username

        self.add_button("Cancelar", Gtk.ResponseType.CANCEL)
        self.add_button("Conectar", Gtk.ResponseType.OK)
        self.set_default_response(Gtk.ResponseType.OK)

        content = self.get_content_area()
        content.set_spacing(10)
        content.set_margin_top(14)
        content.set_margin_bottom(14)
        content.set_margin_start(16)
        content.set_margin_end(16)

        title_lbl = Gtk.Label()
        title_lbl.set_markup(f"<span font='11' weight='bold'>Credenciales para:</span>\n<span color='#89b4fa'>{vpn_name}</span>")
        title_lbl.set_xalign(0)
        content.pack_start(title_lbl, False, False, 4)

        if self.need_username:
            u_lbl = Gtk.Label(label="Usuario:")
            u_lbl.set_xalign(0)
            content.pack_start(u_lbl, False, False, 0)

            self.user_entry = Gtk.Entry()
            self.user_entry.set_text(default_user)
            content.pack_start(self.user_entry, False, False, 0)
        else:
            self.user_entry = None

        p_lbl = Gtk.Label(label="Contraseña / Clave privada:")
        p_lbl.set_xalign(0)
        content.pack_start(p_lbl, False, False, 0)

        self.pass_entry = Gtk.Entry()
        self.pass_entry.set_visibility(False)
        self.pass_entry.set_invisible_char("●")
        self.pass_entry.connect("activate", lambda e: self.response(Gtk.ResponseType.OK))
        content.pack_start(self.pass_entry, False, False, 0)

        self.save_check = Gtk.CheckButton(label="Recordar credenciales para esta VPN")
        self.save_check.set_active(True)
        content.pack_start(self.save_check, False, False, 4)

        self.show_all()

    def get_credentials(self):
        user = self.user_entry.get_text().strip() if self.user_entry else ""
        pwd = self.pass_entry.get_text()
        remember = self.save_check.get_active()
        return user, pwd, remember


class VPNMenuApp(Gtk.Window):
    def __init__(self):
        super().__init__(title="VPNMenu - Gestor de Conexiones VPN")
        self.set_default_size(680, 720)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_icon_name("network-vpn")
        
        self.load_css()
        self.is_updating_switches = False
        self.switches_map = {} # vpn_id -> Gtk.Switch

        # Main Layout
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        main_box.set_margin_top(12)
        main_box.set_margin_bottom(12)
        main_box.set_margin_start(16)
        main_box.set_margin_end(16)
        self.add(main_box)

        # Header Title
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        title_icon = Gtk.Label()
        title_icon.set_markup("<span font='18'>󰖂</span>")
        header_box.pack_start(title_icon, False, False, 0)
        
        title_label = Gtk.Label()
        title_label.set_markup("<span font='15' weight='bold'>VPNMenu</span>")
        title_label.set_xalign(0)
        header_box.pack_start(title_label, True, True, 0)

        # Add VPN Button
        add_btn = Gtk.Button()
        add_btn.set_tooltip_text("Añadir archivo .ovpn o .conf")
        add_btn.get_style_context().add_class("btn-action")
        add_btn_label = Gtk.Label()
        add_btn_label.set_markup("<span>➕ Añadir VPN</span>")
        add_btn.add(add_btn_label)
        add_btn.connect("clicked", self.on_add_vpn_clicked)
        header_box.pack_end(add_btn, False, False, 0)

        # Refresh Button
        refresh_btn = Gtk.Button()
        refresh_btn.set_tooltip_text("Refrescar estado")
        refresh_btn.get_style_context().add_class("btn-action")
        refresh_label = Gtk.Label()
        refresh_label.set_markup("<span>🔄</span>")
        refresh_btn.add(refresh_label)
        refresh_btn.connect("clicked", lambda b: self.refresh_all())
        header_box.pack_end(refresh_btn, False, False, 0)

        main_box.pack_start(header_box, False, False, 0)

        # Status Banner
        self.banner_label = Gtk.Label()
        if IS_ROOT:
            self.banner_label.set_markup("<span color='#a6e3a1' font='10'>⚡ <b>Modo ROOT Activo:</b> Las conexiones se ejecutan directamente con privilegios máximos.</span>")
        else:
            self.banner_label.set_markup("<span color='#89b4fa' font='10'>💡 <b>Modo Usuario:</b> Se solicitará autenticación polkit/root al activar las conexiones.</span>")
        self.banner_label.set_xalign(0)
        main_box.pack_start(self.banner_label, False, False, 0)

        # Notebook (Tabs)
        self.notebook = Gtk.Notebook()
        main_box.pack_start(self.notebook, True, True, 0)

        # Tab 1: Conexiones & Info
        tab1_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        tab1_box.set_margin_top(8)
        tab1_box.set_margin_bottom(8)
        tab1_box.set_margin_start(4)
        tab1_box.set_margin_end(4)

        # Live Info Card
        active_frame = Gtk.Frame()
        active_frame.get_style_context().add_class("active-frame")
        active_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        active_box.set_margin_top(10)
        active_box.set_margin_bottom(10)
        active_box.set_margin_start(12)
        active_box.set_margin_end(12)
        active_frame.add(active_box)

        active_title = Gtk.Label()
        active_title.set_markup("<span weight='bold' font='11' color='#5eead4'>󱘖 Conexiones Activas e Información de Red</span>")
        active_title.set_xalign(0)
        active_box.pack_start(active_title, False, False, 0)

        self.active_info_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        active_box.pack_start(self.active_info_container, True, True, 0)
        tab1_box.pack_start(active_frame, False, False, 0)

        # VPN List
        list_label = Gtk.Label()
        list_label.set_markup("<span weight='bold' font='11'>Todas las Conexiones Disponibles</span>")
        list_label.set_xalign(0)
        tab1_box.pack_start(list_label, False, False, 2)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_min_content_height(240)
        
        self.vpn_list_box = Gtk.ListBox()
        self.vpn_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.vpn_list_box.get_style_context().add_class("vpn-list")
        scrolled.add(self.vpn_list_box)
        tab1_box.pack_start(scrolled, True, True, 0)

        # Disconnect All Button
        disconn_all_btn = Gtk.Button(label="󰌙 Desconectar Todas las VPNs")
        disconn_all_btn.get_style_context().add_class("btn-danger")
        disconn_all_btn.connect("clicked", self.on_disconnect_all)
        tab1_box.pack_start(disconn_all_btn, False, False, 0)

        tab1_label = Gtk.Label(label="󰖂 Conexiones")
        self.notebook.append_page(tab1_box, tab1_label)

        # Tab 2: Terminal de Ejecución y Logs
        tab2_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        tab2_box.set_margin_top(8)
        tab2_box.set_margin_bottom(8)
        tab2_box.set_margin_start(4)
        tab2_box.set_margin_end(4)

        term_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        term_title = Gtk.Label()
        term_title.set_markup("<span weight='bold' font='11' color='#f9e2af'> Terminal de Comandos y Registro de Errores</span>")
        term_title.set_xalign(0)
        term_header.pack_start(term_title, True, True, 0)

        clear_btn = Gtk.Button(label="🗑 Limpiar")
        clear_btn.get_style_context().add_class("btn-action")
        clear_btn.connect("clicked", lambda b: self.clear_logs())
        term_header.pack_end(clear_btn, False, False, 0)
        tab2_box.pack_start(term_header, False, False, 0)

        log_scroll = Gtk.ScrolledWindow()
        log_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_scroll.get_style_context().add_class("terminal-view")

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_monospace(True)
        self.log_view.set_left_margin(10)
        self.log_view.set_right_margin(10)
        self.log_view.set_top_margin(10)
        self.log_view.set_bottom_margin(10)
        self.log_buffer = self.log_view.get_buffer()

        self.tag_cmd = self.log_buffer.create_tag("cmd", foreground="#89b4fa", weight=Pango.Weight.BOLD)
        self.tag_stdout = self.log_buffer.create_tag("stdout", foreground="#cdd6f4")
        self.tag_stderr = self.log_buffer.create_tag("stderr", foreground="#f38ba8", weight=Pango.Weight.BOLD)
        self.tag_success = self.log_buffer.create_tag("success", foreground="#a6e3a1", weight=Pango.Weight.BOLD)
        self.tag_info = self.log_buffer.create_tag("info", foreground="#f9e2af")

        log_scroll.add(self.log_view)
        tab2_box.pack_start(log_scroll, True, True, 0)

        tab2_label = Gtk.Label(label=" Terminal & Logs")
        self.notebook.append_page(tab2_box, tab2_label)

        self.log_text("info", "=== VPNMenu iniciado. Sistema listo ===")

        self.refresh_all()
        GLib.timeout_add_seconds(3, self.periodic_refresh)

    def load_css(self):
        css_provider = Gtk.CssProvider()
        css = """
        window {
            background-color: #181825;
            color: #cdd6f4;
            font-family: 'JetBrains Mono', 'Fira Code', 'Segoe UI', sans-serif;
        }
        notebook tab {
            background-color: #1e1e2e;
            color: #a6adc8;
            padding: 8px 16px;
            border-radius: 6px 6px 0 0;
        }
        notebook tab:checked {
            background-color: #313244;
            color: #cdd6f4;
            font-weight: bold;
        }
        .active-frame {
            background-color: #1e1e2e;
            border: 1px solid #313244;
            border-radius: 10px;
        }
        .vpn-list {
            background-color: #1e1e2e;
            border: 1px solid #313244;
            border-radius: 10px;
            padding: 4px;
        }
        .vpn-item {
            background-color: #252538;
            border-radius: 8px;
            margin-bottom: 4px;
            padding: 6px 10px;
        }
        .vpn-item:hover {
            background-color: #313244;
        }
        .btn-action {
            background-color: #313244;
            color: #cdd6f4;
            border-radius: 6px;
            border: none;
            padding: 4px 10px;
        }
        .btn-action:hover {
            background-color: #45475a;
        }
        .btn-danger {
            background-color: #f38ba8;
            color: #11111b;
            font-weight: bold;
            border-radius: 8px;
            border: none;
            padding: 8px;
            margin-top: 4px;
        }
        .btn-danger:hover {
            background-color: #eba0ac;
        }
        .terminal-view {
            background-color: #11111b;
            border: 1px solid #313244;
            border-radius: 8px;
        }
        textview text {
            background-color: #11111b;
            color: #cdd6f4;
        }
        .copy-btn {
            background: transparent;
            border: none;
            padding: 2px 4px;
            color: #89b4fa;
        }
        .copy-btn:hover {
            color: #b4befe;
        }
        switch:checked {
            background-color: #a6e3a1;
        }
        """
        css_provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def log_text(self, tag, text):
        def _append():
            end_iter = self.log_buffer.get_end_iter()
            self.log_buffer.insert_with_tags_by_name(end_iter, text + "\n", tag)
            mark = self.log_buffer.create_mark(None, self.log_buffer.get_end_iter(), False)
            self.log_view.scroll_to_mark(mark, 0.05, True, 0.0, 1.0)
        GLib.idle_add(_append)

    def clear_logs(self):
        self.log_buffer.set_text("")
        self.log_text("info", "=== Registro limpiado ===")

    def periodic_refresh(self):
        self.refresh_all()
        return True

    def refresh_all(self):
        active_interfaces = get_active_interfaces()
        running_info = get_running_processes_info()
        
        # 1. Update Active Connections Frame
        for child in self.active_info_container.get_children():
            self.active_info_container.remove(child)

        if not active_interfaces:
            no_act_lbl = Gtk.Label()
            no_act_lbl.set_markup("<span color='#a6adc8' style='italic'>No hay conexiones VPN activas en este momento.</span>")
            no_act_lbl.set_xalign(0)
            self.active_info_container.pack_start(no_act_lbl, False, False, 2)
        else:
            for ifname, data in active_interfaces.items():
                card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                card.get_style_context().add_class("vpn-item")

                top_line = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
                name_lbl = Gtk.Label()
                name_lbl.set_markup(f"<span font='10' weight='bold' color='#a6e3a1'>● {ifname}</span>  <span color='#89b4fa' font='10'>({data['type']})</span>")
                name_lbl.set_xalign(0)
                top_line.pack_start(name_lbl, True, True, 0)
                card.pack_start(top_line, False, False, 0)

                # IPs
                if data["ips"]:
                    for ip_item in data["ips"]:
                        ip_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                        ip_lbl = Gtk.Label()
                        ip_lbl.set_markup(f"<span color='#cdd6f4' font='9'>  ├─ 󰩟 IP: <b>{ip_item['ip']}</b> (Máscara: {ip_item['netmask']})</span>")
                        ip_lbl.set_xalign(0)
                        ip_box.pack_start(ip_lbl, False, False, 0)

                        copy_btn = Gtk.Button(label="📋 Copiar")
                        copy_btn.get_style_context().add_class("copy-btn")
                        copy_btn.connect("clicked", lambda b, ip=ip_item['ip']: self.copy_to_clipboard(ip, f"IP {ip}"))
                        ip_box.pack_start(copy_btn, False, False, 0)
                        card.pack_start(ip_box, False, False, 0)
                else:
                    no_ip = Gtk.Label()
                    no_ip.set_markup("<span color='#f38ba8' font='9'>  ├─ 󰩟 IP: Sin IPv4 asignada</span>")
                    no_ip.set_xalign(0)
                    card.pack_start(no_ip, False, False, 0)

                # Gateway
                gw_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                gw_lbl = Gtk.Label()
                gw_lbl.set_markup(f"<span color='#cdd6f4' font='9'>  └─ 󰌘 Gateway: <b>{data['gateway']}</b></span>")
                gw_lbl.set_xalign(0)
                gw_box.pack_start(gw_lbl, False, False, 0)

                if data["gateway"] != "Direct / P2P":
                    copy_gw = Gtk.Button(label="📋 Copiar")
                    copy_gw.get_style_context().add_class("copy-btn")
                    copy_gw.connect("clicked", lambda b, gw=data['gateway']: self.copy_to_clipboard(gw, f"Gateway {gw}"))
                    gw_box.pack_start(copy_gw, False, False, 0)

                card.pack_start(gw_box, False, False, 0)
                self.active_info_container.pack_start(card, False, False, 2)

        self.active_info_container.show_all()

        # 2. Gather Defined VPN Profiles
        all_vpns = []
        all_vpns.extend(get_openvpn_configs(running_info))
        
        # FortiClient profile
        fct = dict(FORTICLIENT_DEFAULT)
        fct["active"] = running_info.get("openfortivpn", False) or any("ppp" in k or "fct" in k or "fssl" in k for k in active_interfaces.keys())
        all_vpns.append(fct)

        # ZeroTier profiles
        all_vpns.extend(get_zerotier_entries(active_interfaces))

        # WireGuard & Custom
        all_vpns.extend(get_wireguard_interfaces(running_info))
        all_vpns.extend(get_custom_vpns())

        # Render or update switches
        self.is_updating_switches = True
        
        # Rebuild list if length or items changed
        current_rows = len(self.vpn_list_box.get_children())
        if current_rows != len(all_vpns):
            for row in self.vpn_list_box.get_children():
                self.vpn_list_box.remove(row)
            self.switches_map.clear()

            for vpn in all_vpns:
                row = Gtk.ListBoxRow()
                row.get_style_context().add_class("vpn-item")

                hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                hbox.set_margin_top(4)
                hbox.set_margin_bottom(4)
                hbox.set_margin_start(8)
                hbox.set_margin_end(8)

                icon_lbl = Gtk.Label()
                icon_str = "󰖂"
                if vpn["subtype"] == "wireguard":
                    icon_str = "󰌘"
                elif vpn["subtype"] in ("openfortivpn", "forticlient"):
                    icon_str = "󰒄"
                elif vpn["subtype"] == "openvpn":
                    icon_str = "󰖂"
                elif vpn["subtype"] == "zerotier":
                    icon_str = "󰈀"
                icon_lbl.set_markup(f"<span font='14'>{icon_str}</span>")
                hbox.pack_start(icon_lbl, False, False, 0)

                vbox_text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
                name_lbl = Gtk.Label()
                name_lbl.set_markup(f"<span font='10' weight='bold'>{vpn['name']}</span>")
                name_lbl.set_xalign(0)
                name_lbl.set_ellipsize(Pango.EllipsizeMode.END)
                vbox_text.pack_start(name_lbl, False, False, 0)

                desc_lbl = Gtk.Label()
                path_info = vpn.get("path") or vpn.get("ifname") or vpn.get("host") or vpn.get("type")
                desc_lbl.set_markup(f"<span font='8' color='#a6adc8'>{path_info}</span>")
                desc_lbl.set_xalign(0)
                desc_lbl.set_ellipsize(Pango.EllipsizeMode.MIDDLE)
                vbox_text.pack_start(desc_lbl, False, False, 0)

                hbox.pack_start(vbox_text, True, True, 0)

                # Edit credentials button for openvpn/openfortivpn
                if vpn["subtype"] in ("openfortivpn", "openvpn"):
                    key_btn = Gtk.Button()
                    key_btn.set_tooltip_text("Configurar credenciales")
                    key_btn.get_style_context().add_class("copy-btn")
                    k_lbl = Gtk.Label()
                    k_lbl.set_markup("<span font='11'>🔑</span>")
                    key_btn.add(k_lbl)
                    key_btn.connect("clicked", self.on_edit_credentials, vpn)
                    hbox.pack_start(key_btn, False, False, 0)

                switch = Gtk.Switch()
                switch.set_active(vpn.get("active", False))
                switch.set_valign(Gtk.Align.CENTER)
                switch.connect("state-set", self.on_switch_toggled, vpn)
                hbox.pack_end(switch, False, False, 0)

                self.switches_map[vpn["id"]] = switch

                row.add(hbox)
                self.vpn_list_box.add(row)

            self.vpn_list_box.show_all()
        else:
            for vpn in all_vpns:
                vid = vpn["id"]
                if vid in self.switches_map:
                    self.switches_map[vid].set_active(vpn.get("active", False))

        self.is_updating_switches = False

    def on_edit_credentials(self, btn, vpn):
        saved = get_saved_credentials().get(vpn["id"], {})
        def_user = saved.get("username", vpn.get("username", ""))
        
        dialog = CredentialsDialog(
            self,
            vpn["name"],
            default_user=def_user,
            need_username=(vpn["subtype"] == "openfortivpn" or vpn.get("needs_userpass", True)),
            title="Configurar Credenciales de VPN"
        )
        if saved.get("password"):
            dialog.pass_entry.set_text(saved["password"])

        res = dialog.run()
        if res == Gtk.ResponseType.OK:
            user, pwd, remember = dialog.get_credentials()
            if remember and (user or pwd):
                save_credential(vpn["id"], user, pwd)
                self.set_banner(f"💾 Credenciales guardadas para '{vpn['name']}'.")
            elif not remember:
                creds = get_saved_credentials()
                if vpn["id"] in creds:
                    del creds[vpn["id"]]
                    with open(CREDENTIALS_FILE, "w") as f:
                        json.dump(creds, f, indent=2)
        dialog.destroy()

    def prompt_credentials_sync(self, vpn):
        """Shows credentials dialog on main thread and waits for result."""
        saved = get_saved_credentials().get(vpn["id"], {})
        if saved.get("password") or (vpn["subtype"] == "openfortivpn" and saved.get("password")):
            return saved.get("username", vpn.get("username", "")), saved.get("password"), True

        result = {"user": "", "pwd": "", "remember": False, "cancelled": False}
        evt = threading.Event()

        def _show():
            def_user = saved.get("username", vpn.get("username", ""))
            dialog = CredentialsDialog(
                self,
                vpn["name"],
                default_user=def_user,
                need_username=(vpn["subtype"] == "openfortivpn" or vpn.get("needs_userpass", True))
            )
            res = dialog.run()
            if res == Gtk.ResponseType.OK:
                u, p, rem = dialog.get_credentials()
                result["user"] = u
                result["pwd"] = p
                result["remember"] = rem
            else:
                result["cancelled"] = True
            dialog.destroy()
            evt.set()

        GLib.idle_add(_show)
        evt.wait()

        if result["cancelled"]:
            return None, None, False

        if result["remember"] and (result["user"] or result["pwd"]):
            save_credential(vpn["id"], result["user"], result["pwd"])

        return result["user"], result["pwd"], True

    def on_switch_toggled(self, switch, state, vpn):
        if self.is_updating_switches:
            return False

        threading.Thread(target=self._toggle_vpn_worker, args=(vpn, state), daemon=True).start()
        return False

    def _toggle_vpn_worker(self, vpn, target_state):
        subtype = vpn.get("subtype")
        vpn_name = vpn.get("name")
        success = False

        action_str = "Levantando" if target_state else "Apagando"
        self.set_banner(f"⏳ {action_str} '{vpn_name}'...")
        self.log_text("info", f"\n>>> [{time.strftime('%H:%M:%S')}] Iniciando acción: {action_str} '{vpn_name}'...")

        if target_state:
            # Turn ON
            if subtype == "openvpn":
                path = vpn.get("path")
                # Check if credentials needed
                needs_userpass, needs_keypass = check_ovpn_needs_credentials(path)
                
                auth_file_path = None
                extra_args = []
                
                if needs_userpass or needs_keypass:
                    user, pwd, ok = self.prompt_credentials_sync(vpn)
                    if not ok:
                        self.log_text("stderr", "[-] Conexión cancelada por el usuario (sin credenciales).")
                        GLib.idle_add(self._post_toggle, vpn_name, target_state, False)
                        return

                    # Create secure temporary auth file
                    auth_fd, auth_file_path = tempfile.mkstemp(prefix="ovpn_auth_")
                    with os.fdopen(auth_fd, "w") as af:
                        if user:
                            af.write(f"{user}\n")
                        af.write(f"{pwd}\n")
                    os.chmod(auth_file_path, 0o600)
                    
                    if needs_userpass:
                        extra_args.extend(["--auth-user-pass", auth_file_path])
                    if needs_keypass:
                        extra_args.extend(["--askpass", auth_file_path])

                cmd = wrap_root_cmd(["openvpn", "--config", path, "--daemon", f"ovpn_{os.path.basename(path)}"] + extra_args)
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                
                # Cleanup temp auth file
                if auth_file_path and os.path.exists(auth_file_path):
                    try: os.remove(auth_file_path)
                    except Exception: pass

                success = (res.returncode == 0)

            elif subtype == "openfortivpn":
                host = vpn.get("host", "158.251.3.2:50443")
                cert = vpn.get("trusted_cert", "69fb7b8d4d3beb137abf3b339a3e14ec68831d0f718704b3709c1afd7d8d0298")
                
                user, pwd, ok = self.prompt_credentials_sync(vpn)
                if not ok:
                    self.log_text("stderr", "[-] Conexión cancelada por el usuario (sin credenciales).")
                    GLib.idle_add(self._post_toggle, vpn_name, target_state, False)
                    return

                # Build openfortivpn command
                base_cmd = ["openfortivpn", host, "-u", user, f"--trusted-cert={cert}"]
                if pwd:
                    base_cmd.extend(["-p", pwd])
                
                cmd = wrap_root_cmd(base_cmd)
                
                self.log_text("cmd", f"$ {' '.join(cmd[:-1])} -p [REDACTED]")
                
                try:
                    proc = subprocess.Popen(
                        cmd,
                        stdin=subprocess.DEVNULL,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        text=True,
                        bufsize=1
                    )

                    def _stream_output(p):
                        for line in iter(p.stdout.readline, ''):
                            if line:
                                self.log_text("stdout", line.rstrip())
                        for line in iter(p.stderr.readline, ''):
                            if line:
                                self.log_text("stderr", line.rstrip())

                    threading.Thread(target=_stream_output, args=(proc,), daemon=True).start()

                    # Wait dynamically for either connection interface to appear or user authentication
                    # Wait up to 25 seconds for pkexec auth + tunnel establishment
                    connected = False
                    for _ in range(25):
                        time.sleep(1)
                        if proc.poll() is not None:
                            # Process died
                            break
                        # Check if any ppp / fct / vpn tunnel came up or running
                        active_devs = get_active_interfaces()
                        if any("ppp" in k or "fct" in k or "fssl" in k or "tun" in k for k in active_devs.keys()):
                            connected = True
                            break

                    if proc.poll() is None or connected:
                        success = True
                        self.log_text("success", "[+] openfortivpn autenticado y túnel establecido en segundo plano.")
                    else:
                        success = False
                        self.log_text("stderr", "[-] openfortivpn terminó o no se pudo establecer la conexión.")
                except Exception as e:
                    self.log_text("stderr", f"Error al ejecutar openfortivpn: {e}")
                    success = False

            elif subtype == "zerotier":
                ifname = vpn.get("ifname", "ztu7tpupze")
                cmd = wrap_root_cmd(["ip", "link", "set", ifname, "up"])
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                success = (res.returncode == 0)

            elif subtype == "wireguard":
                path = vpn.get("path")
                ifname = vpn.get("ifname")
                cmd = wrap_root_cmd(["wg-quick", "up", path or ifname])
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                success = (res.returncode == 0)

        else:
            # Turn OFF
            if subtype == "openvpn":
                path = vpn.get("path")
                bname = os.path.basename(path)
                cmd = wrap_root_cmd(["pkill", "-9", "-f", bname])
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                success = True

            elif subtype == "openfortivpn":
                cmd = wrap_root_cmd(["pkill", "-9", "-f", "openfortivpn"])
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                success = True

            elif subtype == "zerotier":
                ifname = vpn.get("ifname", "ztu7tpupze")
                cmd = wrap_root_cmd(["ip", "link", "set", ifname, "down"])
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                success = True

            elif subtype == "wireguard":
                path = vpn.get("path")
                ifname = vpn.get("ifname")
                cmd = wrap_root_cmd(["wg-quick", "down", path or ifname])
                self.log_text("cmd", f"$ {' '.join(cmd)}")
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.stdout: self.log_text("stdout", res.stdout)
                if res.stderr: self.log_text("stderr", res.stderr)
                success = True

        GLib.idle_add(self._post_toggle, vpn_name, target_state, success)

    def _post_toggle(self, name, state, success):
        action = "conectada" if state else "desconectada"
        if success:
            self.set_banner(f"✅ VPN '{name}' {action} con éxito.")
            self.log_text("success", f"[✓] VPN '{name}' {action} correctamente.\n")
            subprocess.run(["notify-send", "VPNMenu", f"VPN '{name}' {action}."])
        else:
            self.set_banner(f"⚠️ Error al cambiar estado de '{name}'. Ver pestaña Terminal.")
            self.log_text("stderr", f"[✗] Fallo al intentar {action} la VPN '{name}'. Revisa los logs arriba.\n")
            subprocess.run(["notify-send", "VPNMenu Error", f"No se pudo completar la acción en '{name}'."])
            self.notebook.set_current_page(1)
        
        time.sleep(1)
        self.refresh_all()

    def set_banner(self, text):
        def _set():
            self.banner_label.set_markup(f"<span color='#89b4fa' font='10'>{text}</span>")
        GLib.idle_add(_set)

    def copy_to_clipboard(self, text, desc):
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text(text, -1)
        subprocess.run(["wl-copy", text])
        subprocess.run(["notify-send", "VPNMenu Copiado", f"{desc} copiado al portapapeles"])
        self.log_text("info", f"[i] Portapapeles: {desc}")

    def on_add_vpn_clicked(self, btn):
        dialog = Gtk.FileChooserDialog(
            title="Seleccionar archivo de configuración VPN (.ovpn / .conf)",
            parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )

        filter_vpn = Gtk.FileFilter()
        filter_vpn.set_name("Archivos VPN (*.ovpn, *.conf)")
        filter_vpn.add_pattern("*.ovpn")
        filter_vpn.add_pattern("*.conf")
        dialog.add_filter(filter_vpn)

        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            filepath = dialog.get_filename()
            if filepath:
                self.add_custom_vpn(filepath)
        dialog.destroy()

    def add_custom_vpn(self, filepath):
        customs = get_custom_vpns()
        bname = os.path.basename(filepath)
        subtype = "openvpn" if filepath.endswith(".ovpn") else "wireguard"
        name = f"Custom: {bname}"
        
        if any(c.get("path") == filepath for c in customs):
            self.set_banner(f"⚠️ El archivo '{bname}' ya estaba añadido.")
            return

        customs.append({
            "id": f"custom_{bname}",
            "name": name,
            "type": "OpenVPN" if subtype == "openvpn" else "WireGuard",
            "subtype": subtype,
            "path": filepath,
            "active": False
        })
        save_custom_vpns(customs)
        self.set_banner(f"✅ VPN '{bname}' agregada al menú.")
        self.log_text("info", f"[+] Nueva VPN añadida: {filepath}")
        self.refresh_all()

    def on_disconnect_all(self, btn):
        def _worker():
            self.set_banner("⏳ Desconectando todas las VPNs activas...")
            self.log_text("info", "\n>>> Desconectando todas las VPNs...")
            
            # Kill openvpn
            cmd_ovpn = ["pkexec", "pkill", "-9", "-f", "openvpn"]
            self.log_text("cmd", f"$ {' '.join(cmd_ovpn)}")
            subprocess.run(cmd_ovpn)
            
            # Kill openfortivpn
            cmd_forti = ["pkexec", "pkill", "-9", "-f", "openfortivpn|forti"]
            self.log_text("cmd", f"$ {' '.join(cmd_forti)}")
            subprocess.run(cmd_forti)

            # Down wireguard active
            active = get_active_interfaces()
            for ifname, d in active.items():
                if d["type"] == "WireGuard":
                    cmd_wg = ["pkexec", "wg-quick", "down", ifname]
                    self.log_text("cmd", f"$ {' '.join(cmd_wg)}")
                    subprocess.run(cmd_wg)
                elif d["type"] == "ZeroTier":
                    cmd_zt = ["pkexec", "ip", "link", "set", ifname, "down"]
                    self.log_text("cmd", f"$ {' '.join(cmd_zt)}")
                    subprocess.run(cmd_zt)
            
            self.log_text("success", "[✓] Todas las conexiones VPN han sido terminadas.\n")
            GLib.idle_add(self.refresh_all)
            GLib.idle_add(lambda: self.set_banner("✅ Todas las VPNs fueron desconectadas."))
            subprocess.run(["notify-send", "VPNMenu", "Todas las VPNs han sido desconectadas."])

        threading.Thread(target=_worker, daemon=True).start()


def main():
    app = VPNMenuApp()
    app.connect("destroy", Gtk.main_quit)
    app.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
