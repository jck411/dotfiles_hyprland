#!/usr/bin/env python3
"""Power & Display Settings for Hyprland/Waybar - GTK3"""

import gi
import os
import subprocess

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Pango

CONFIG_FILE = os.path.expanduser("~/.config/power-settings.conf")


class PowerSettingsWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Power Settings")
        self.set_resizable(True)
        self.set_default_size(400, -1)
        
        # Load config
        self.config = self.load_config()
        
        # Main container with padding
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.set_margin_top(24)
        main_box.set_margin_bottom(24)
        main_box.set_margin_start(24)
        main_box.set_margin_end(24)
        self.add(main_box)
        
        # === Screen Section ===
        main_box.pack_start(self.create_section_label("Screen"), False, False, 0)
        
        screen_frame = Gtk.Frame()
        screen_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        screen_frame.add(screen_box)
        main_box.pack_start(screen_frame, False, False, 0)
        
        # Screensaver row
        ss_row, self.screensaver_switch = self.create_switch_row("Screensaver")
        self.screensaver_switch.set_active(self.config.get("screensaver_enabled", True))
        screen_box.pack_start(ss_row, False, False, 0)
        
        # Timeout row
        timeout_row, self.screensaver_spin = self.create_spin_row("Timeout (minutes)", 1, 60)
        self.screensaver_spin.set_value(self.config.get("screensaver_timeout", 5))
        screen_box.pack_start(timeout_row, False, False, 0)
        
        # === Session Section ===
        main_box.pack_start(self.create_section_label("Session"), False, False, 0)
        
        session_frame = Gtk.Frame()
        session_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        session_frame.add(session_box)
        main_box.pack_start(session_frame, False, False, 0)
        
        # Auto log off row
        lo_row, self.logoff_switch = self.create_switch_row("Auto Log Off")
        self.logoff_switch.set_active(self.config.get("auto_logoff_enabled", False))
        session_box.pack_start(lo_row, False, False, 0)
        
        # Timeout row
        lo_timeout_row, self.logoff_spin = self.create_spin_row("Timeout (minutes)", 1, 120)
        self.logoff_spin.set_value(self.config.get("auto_logoff_timeout", 10))
        session_box.pack_start(lo_timeout_row, False, False, 0)
        
        # === Laptop Section ===
        main_box.pack_start(self.create_section_label("Laptop"), False, False, 0)
        
        lid_frame = Gtk.Frame()
        lid_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        lid_frame.add(lid_box)
        main_box.pack_start(lid_frame, False, False, 0)
        
        # Lid close action
        lid_row, self.lid_combo = self.create_combo_row("On Lid Close", ["Suspend", "Lock", "Power Off", "Ignore"])
        lid_action = self.config.get("lid_close_action", "suspend")
        lid_index = {"suspend": 0, "lock": 1, "poweroff": 2, "ignore": 3}.get(lid_action, 0)
        self.lid_combo.set_active(lid_index)
        lid_box.pack_start(lid_row, False, False, 0)
        
        # Buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        button_box.set_halign(Gtk.Align.END)
        button_box.set_margin_top(24)
        main_box.pack_start(button_box, False, False, 0)
        
        cancel_btn = Gtk.Button(label="Cancel")
        cancel_btn.connect("clicked", lambda _: self.destroy())
        button_box.pack_start(cancel_btn, False, False, 0)
        
        save_btn = Gtk.Button(label="Save")
        save_btn.get_style_context().add_class("suggested-action")
        save_btn.connect("clicked", self.on_save)
        button_box.pack_start(save_btn, False, False, 0)
        
        self.connect("destroy", Gtk.main_quit)
        self.show_all()
    
    def create_section_label(self, text):
        label = Gtk.Label(label=text, xalign=0)
        label.set_margin_top(16)
        label.set_margin_bottom(8)
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_weight_new(Pango.Weight.BOLD))
        label.set_attributes(attrs)
        return label
    
    def create_switch_row(self, title):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.set_margin_top(12)
        row.set_margin_bottom(12)
        row.set_margin_start(12)
        row.set_margin_end(12)
        
        label = Gtk.Label(label=title, xalign=0)
        label.set_hexpand(True)
        row.pack_start(label, True, True, 0)
        
        switch = Gtk.Switch()
        switch.set_valign(Gtk.Align.CENTER)
        row.pack_start(switch, False, False, 0)
        
        return row, switch
    
    def create_spin_row(self, title, min_val, max_val):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.set_margin_top(12)
        row.set_margin_bottom(12)
        row.set_margin_start(12)
        row.set_margin_end(12)
        
        label = Gtk.Label(label=title, xalign=0)
        label.set_hexpand(True)
        row.pack_start(label, True, True, 0)
        
        adj = Gtk.Adjustment(value=5, lower=min_val, upper=max_val, step_increment=1, page_increment=5, page_size=0)
        spin = Gtk.SpinButton()
        spin.set_adjustment(adj)
        spin.set_numeric(True)
        spin.set_width_chars(4)
        row.pack_start(spin, False, False, 0)
        
        return row, spin
    
    def create_combo_row(self, title, options):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.set_margin_top(12)
        row.set_margin_bottom(12)
        row.set_margin_start(12)
        row.set_margin_end(12)
        
        label = Gtk.Label(label=title, xalign=0)
        label.set_hexpand(True)
        row.pack_start(label, True, True, 0)
        
        combo = Gtk.ComboBoxText()
        for option in options:
            combo.append_text(option)
        row.pack_start(combo, False, False, 0)
        
        return row, combo
    
    def load_config(self):
        config = {
            "screensaver_enabled": True,
            "screensaver_timeout": 5,
            "auto_logoff_enabled": False,
            "auto_logoff_timeout": 10,
            "lid_close_action": "suspend"
        }
        
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    for line in f:
                        if '=' in line:
                            key, value = line.strip().split('=', 1)
                            value = value.strip('"')
                            if key == "SCREENSAVER_ENABLED":
                                config["screensaver_enabled"] = value == "true"
                            elif key == "SCREENSAVER_TIMEOUT":
                                config["screensaver_timeout"] = int(value) // 60
                            elif key == "AUTO_LOGOFF_ENABLED":
                                config["auto_logoff_enabled"] = value == "true"
                            elif key == "AUTO_LOGOFF_TIMEOUT":
                                config["auto_logoff_timeout"] = int(value) // 60
                            elif key == "LID_CLOSE_ACTION":
                                config["lid_close_action"] = value
            except:
                pass
        
        return config
    
    def on_save(self, button):
        ss_enabled = self.screensaver_switch.get_active()
        ss_timeout = int(self.screensaver_spin.get_value()) * 60
        lo_enabled = self.logoff_switch.get_active()
        lo_timeout = int(self.logoff_spin.get_value()) * 60
        lid_actions = ["suspend", "lock", "poweroff", "ignore"]
        lid_action = lid_actions[self.lid_combo.get_active()]
        
        with open(CONFIG_FILE, 'w') as f:
            f.write(f'SCREENSAVER_ENABLED="{"true" if ss_enabled else "false"}"\n')
            f.write(f'SCREENSAVER_TIMEOUT="{ss_timeout}"\n')
            f.write(f'AUTO_LOGOFF_ENABLED="{"true" if lo_enabled else "false"}"\n')
            f.write(f'AUTO_LOGOFF_TIMEOUT="{lo_timeout}"\n')
            f.write(f'LID_CLOSE_ACTION="{lid_action}"\n')
        
        subprocess.run(["notify-send", "-i", "preferences-system", "Power Settings", "Settings saved"])
        self.destroy()


if __name__ == "__main__":
    win = PowerSettingsWindow()
    Gtk.main()
