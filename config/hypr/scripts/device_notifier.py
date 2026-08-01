#!/usr/bin/env python3
"""
Device Notifier Daemon for Hyprland + SwayNC
Monitors USB/Storage mounts and Bluetooth connection events and sends system notifications via notify-send.
"""

import subprocess
import gi
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

def send_notification(summary, body, icon="drive-removable-media", app_name="Device Monitor"):
    try:
        subprocess.run([
            "notify-send",
            "-a", app_name,
            "-i", icon,
            summary,
            body
        ], check=False)
    except Exception as e:
        print(f"[DeviceNotifier] Error sending notification: {e}")

# Volume / Drive callbacks
def on_drive_connected(monitor, drive):
    name = drive.get_name()
    send_notification("Dispositivo Conectado", f"Se ha conectado: {name}", icon="drive-removable-media")

def on_drive_disconnected(monitor, drive):
    name = drive.get_name()
    send_notification("Dispositivo Desconectado", f"Se ha desconectado: {name}", icon="drive-removable-media")

def on_volume_added(monitor, volume):
    name = volume.get_name()
    send_notification("Volumen de Almacenamiento", f"Unidad disponible: {name}", icon="drive-harddisk")

def on_volume_removed(monitor, volume):
    name = volume.get_name()
    send_notification("Volumen Removido", f"Unidad removida: {name}", icon="drive-harddisk")

# Bluetooth DBus listener
def setup_bluetooth_listener():
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        
        def on_dbus_signal(connection, sender_name, object_path, interface_name, signal_name, parameters, user_data):
            if interface_name == "org.freedesktop.DBus.Properties" and signal_name == "PropertiesChanged":
                if len(parameters) >= 2 and parameters[0] == "org.bluez.Device1":
                    changed_props = parameters[1]
                    if "Connected" in changed_props:
                        is_connected = bool(changed_props["Connected"])
                        dev_name = object_path.split("/")[-1].replace("_", ":")
                        try:
                            res = subprocess.check_output(
                                ["bluetoothctl", "info", dev_name],
                                stderr=subprocess.DEVNULL, text=True
                            )
                            for line in res.splitlines():
                                if "Name:" in line:
                                    dev_name = line.split("Name:", 1)[1].strip()
                                    break
                        except Exception:
                            pass
                        
                        if is_connected:
                            send_notification("Bluetooth Conectado", f"Dispositivo conectado: {dev_name}", icon="bluetooth")
                        else:
                            send_notification("Bluetooth Desconectado", f"Dispositivo desconectado: {dev_name}", icon="bluetooth")
        
        bus.signal_subscribe(
            None,
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            None,
            None,
            Gio.DBusSignalFlags.NONE,
            on_dbus_signal,
            None
        )
    except Exception as e:
        print(f"[DeviceNotifier] Bluetooth monitoring error: {e}")

def main():
    vm = Gio.VolumeMonitor.get()
    vm.connect("drive-connected", on_drive_connected)
    vm.connect("drive-disconnected", on_drive_disconnected)
    vm.connect("volume-added", on_volume_added)
    vm.connect("volume-removed", on_volume_removed)
    
    setup_bluetooth_listener()
    
    loop = GLib.MainLoop()
    loop.run()

if __name__ == "__main__":
    main()
