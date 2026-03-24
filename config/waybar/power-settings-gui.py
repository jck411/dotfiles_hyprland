#!/usr/bin/env python3
"""Power & Display Settings for Hyprland/Waybar - GTK3
Dock-aware: separate settings for docked (external monitor) and undocked (laptop only)."""

import gi
import os
import subprocess

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Pango

CONFIG_FILE = os.path.expanduser("~/.config/power-settings.conf")
APPLY_SCRIPT = os.path.expanduser("~/.config/scripts/apply-power-settings.sh")

DEFAULTS = {
    "UNDOCKED_SCREENSAVER_ENABLED": "false",
    "UNDOCKED_SCREENSAVER_TIMEOUT": "300",
    "UNDOCKED_AUTO_LOGOFF_ENABLED": "false",
    "UNDOCKED_AUTO_LOGOFF_TIMEOUT": "600",
    "UNDOCKED_LID_CLOSE_ACTION": "poweroff",
    "DOCKED_SCREENSAVER_ENABLED": "true",
    "DOCKED_SCREENSAVER_TIMEOUT": "300",
    "DOCKED_AUTO_LOGOFF_ENABLED": "false",
    "DOCKED_AUTO_LOGOFF_TIMEOUT": "600",
    "DOCKED_LID_CLOSE_ACTION": "ignore",
}

LID_ACTIONS = ["suspend", "lock", "poweroff", "ignore"]
LID_LABELS = ["Suspend", "Lock", "Power Off", "Ignore"]


class PowerSettingsWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Power Settings")
        self.set_resizable(True)
        self.set_default_size(420, -1)

        self.config = self.load_config()

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.set_margin_top(24)
        main_box.set_margin_bottom(24)
        main_box.set_margin_start(24)
        main_box.set_margin_end(24)
        self.add(main_box)

        # === When Undocked ===
        main_box.pack_start(self.create_header_label("When Undocked (laptop only)"), False, False, 0)
        self.undocked = self.create_settings_section(main_box, "UNDOCKED")

        # === When Docked ===
        main_box.pack_start(self.create_header_label("When Docked (external monitor)"), False, False, 0)
        self.docked = self.create_settings_section(main_box, "DOCKED")

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

    def create_header_label(self, text):
        label = Gtk.Label(label=text, xalign=0)
        label.set_margin_top(20)
        label.set_margin_bottom(8)
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_weight_new(Pango.Weight.BOLD))
        attrs.insert(Pango.attr_scale_new(1.1))
        label.set_attributes(attrs)
        return label

    def create_settings_section(self, parent, prefix):
        """Create a frame with screensaver, auto-logoff, and lid settings for one dock state."""
        frame = Gtk.Frame()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        frame.add(box)
        parent.pack_start(frame, False, False, 0)

        widgets = {}

        # Screensaver
        box.pack_start(self.create_section_label("Screen"), False, False, 0)
        row, switch = self.create_switch_row("Screensaver")
        switch.set_active(self.config.get(f"{prefix}_SCREENSAVER_ENABLED") == "true")
        box.pack_start(row, False, False, 0)
        widgets["screensaver_switch"] = switch

        row, spin = self.create_spin_row("Timeout (minutes)", 1, 60)
        spin.set_value(int(self.config.get(f"{prefix}_SCREENSAVER_TIMEOUT", "300")) // 60)
        box.pack_start(row, False, False, 0)
        widgets["screensaver_spin"] = spin

        # Auto log off
        box.pack_start(self.create_section_label("Session"), False, False, 0)
        row, switch = self.create_switch_row("Auto Log Off")
        switch.set_active(self.config.get(f"{prefix}_AUTO_LOGOFF_ENABLED") == "true")
        box.pack_start(row, False, False, 0)
        widgets["logoff_switch"] = switch

        row, spin = self.create_spin_row("Timeout (minutes)", 1, 120)
        spin.set_value(int(self.config.get(f"{prefix}_AUTO_LOGOFF_TIMEOUT", "600")) // 60)
        box.pack_start(row, False, False, 0)
        widgets["logoff_spin"] = spin

        # Lid close action
        box.pack_start(self.create_section_label("Laptop"), False, False, 0)
        row, combo = self.create_combo_row("On Lid Close", LID_LABELS)
        action = self.config.get(f"{prefix}_LID_CLOSE_ACTION", "suspend")
        combo.set_active(LID_ACTIONS.index(action) if action in LID_ACTIONS else 0)
        box.pack_start(row, False, False, 0)
        widgets["lid_combo"] = combo

        return widgets

    def create_section_label(self, text):
        label = Gtk.Label(label=text, xalign=0)
        label.set_margin_top(12)
        label.set_margin_bottom(4)
        label.set_margin_start(12)
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_weight_new(Pango.Weight.SEMIBOLD))
        label.set_attributes(attrs)
        return label

    def create_switch_row(self, title):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.set_margin_top(8)
        row.set_margin_bottom(8)
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
        row.set_margin_top(8)
        row.set_margin_bottom(8)
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
        row.set_margin_top(8)
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
        config = dict(DEFAULTS)
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if '=' in line and not line.startswith('#'):
                            key, value = line.split('=', 1)
                            config[key.strip()] = value.strip().strip('"')
            except Exception:
                pass
        return config

    def get_section_values(self, widgets, prefix):
        ss_enabled = widgets["screensaver_switch"].get_active()
        ss_timeout = int(widgets["screensaver_spin"].get_value()) * 60
        lo_enabled = widgets["logoff_switch"].get_active()
        lo_timeout = int(widgets["logoff_spin"].get_value()) * 60
        lid_action = LID_ACTIONS[widgets["lid_combo"].get_active()]
        return {
            f"{prefix}_SCREENSAVER_ENABLED": "true" if ss_enabled else "false",
            f"{prefix}_SCREENSAVER_TIMEOUT": str(ss_timeout),
            f"{prefix}_AUTO_LOGOFF_ENABLED": "true" if lo_enabled else "false",
            f"{prefix}_AUTO_LOGOFF_TIMEOUT": str(lo_timeout),
            f"{prefix}_LID_CLOSE_ACTION": lid_action,
        }

    def on_save(self, button):
        undocked = self.get_section_values(self.undocked, "UNDOCKED")
        docked = self.get_section_values(self.docked, "DOCKED")

        with open(CONFIG_FILE, 'w') as f:
            f.write("# Power settings — dock-aware configuration\n")
            f.write("# Applied by apply-power-settings.sh on dock/undock transitions\n\n")
            f.write("# When undocked (laptop only)\n")
            for key in ["UNDOCKED_SCREENSAVER_ENABLED", "UNDOCKED_SCREENSAVER_TIMEOUT",
                        "UNDOCKED_AUTO_LOGOFF_ENABLED", "UNDOCKED_AUTO_LOGOFF_TIMEOUT",
                        "UNDOCKED_LID_CLOSE_ACTION"]:
                f.write(f'{key}="{undocked[key]}"\n')
            f.write("\n# When docked (external monitor connected)\n")
            for key in ["DOCKED_SCREENSAVER_ENABLED", "DOCKED_SCREENSAVER_TIMEOUT",
                        "DOCKED_AUTO_LOGOFF_ENABLED", "DOCKED_AUTO_LOGOFF_TIMEOUT",
                        "DOCKED_LID_CLOSE_ACTION"]:
                f.write(f'{key}="{docked[key]}"\n')

        # Apply settings immediately
        subprocess.Popen([APPLY_SCRIPT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["notify-send", "-i", "preferences-system", "Power Settings", "Settings saved and applied"])
        self.destroy()


if __name__ == "__main__":
    win = PowerSettingsWindow()
    Gtk.main()
