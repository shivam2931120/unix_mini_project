import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

export default class UnixToolkitLauncher extends Extension {
    enable() {
        this._indicator = new PanelMenu.Button(0.0, this.metadata.name, false);

        this._indicator.add_child(new St.Icon({
            icon_name: 'utilities-terminal-symbolic',
            style_class: 'system-status-icon',
        }));

        const launchItem = new PopupMenu.PopupMenuItem('Open Linux Utility Toolkit');
        launchItem.connect('activate', () => this._launchToolkit());
        this._indicator.menu.addMenuItem(launchItem);

        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }

    _launchToolkit() {
        const executable = GLib.find_program_in_path('unix-toolkit');

        if (!executable) {
            Main.notifyError(this.metadata.name, 'Install the unix-utility-suite .deb package first.');
            return;
        }

        try {
            Gio.Subprocess.new([executable], Gio.SubprocessFlags.NONE);
        } catch (error) {
            console.error(error);
            Main.notifyError(this.metadata.name, 'Could not launch unix-toolkit.');
        }
    }
}
