import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const TOOLKIT_COMMAND = 'unix-toolkit';
const SHORTCUT_KEY = 'launcher-shortcut';
const INSTALL_URL = 'https://github.com/shivam2931120/unix_mini_project/releases/tag/v1.1.0';

const ACTIONS = [
    ['show-system-info', 'System Info', '--system-info'],
    ['show-file-search', 'File Search', '--file-search'],
    ['show-process-manager', 'Process Manager', '--process-manager'],
    ['show-network-monitor', 'Network Monitor', '--network-monitor'],
    ['show-scheduling-simulator', 'Scheduling Simulator', '--scheduling-simulator'],
];

export default class UnixToolkitLauncher extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._settingsChangedId = this._settings.connect('changed', () => {
            this._buildMenu();
            this._registerShortcut();
        });

        this._indicator = new PanelMenu.Button(0.0, this.metadata.name, false);

        this._indicator.add_child(new St.Icon({
            icon_name: 'utilities-terminal-symbolic',
            style_class: 'system-status-icon',
        }));

        Main.panel.addToStatusArea(this.uuid, this._indicator);
        this._buildMenu();
        this._registerShortcut();
    }

    disable() {
        this._unregisterShortcut();

        if (this._settingsChangedId) {
            this._settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = null;
        }

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        this._settings = null;
    }

    _buildMenu() {
        this._indicator.menu.removeAll();

        const executable = this._findToolkit();
        if (!executable) {
            const missingItem = new PopupMenu.PopupMenuItem('unix-toolkit is not installed');
            missingItem.setSensitive(false);
            this._indicator.menu.addMenuItem(missingItem);

            this._addMenuAction('Open GitHub Releases', () => this._openInstallPage());
            this._addMenuAction('Install Help', () => this._showInstallHelp());
            this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            this._addMenuAction('Preferences', () => this.openPreferences());
            return;
        }

        if (this._settings.get_boolean('show-full-launcher'))
            this._addMenuAction('Open Full Toolkit', () => this._launchToolkit('--launcher'));

        for (const [settingKey, label, option] of ACTIONS) {
            if (this._settings.get_boolean(settingKey))
                this._addMenuAction(label, () => this._launchToolkit(option));
        }

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._addMenuAction('Preferences', () => this.openPreferences());
        this._addMenuAction('GitHub Releases', () => this._openInstallPage());
    }

    _addMenuAction(label, callback) {
        const item = new PopupMenu.PopupMenuItem(label);
        item.connect('activate', callback);
        this._indicator.menu.addMenuItem(item);
    }

    _findToolkit() {
        const executable = GLib.find_program_in_path(TOOLKIT_COMMAND);
        if (executable)
            return executable;

        const paths = [
            GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', TOOLKIT_COMMAND]),
            `/usr/local/bin/${TOOLKIT_COMMAND}`,
            `/usr/bin/${TOOLKIT_COMMAND}`,
        ];

        return paths.find(path => GLib.file_test(path, GLib.FileTest.IS_EXECUTABLE)) ?? null;
    }

    _launchToolkit(option = '--launcher') {
        const executable = this._findToolkit();

        if (!executable) {
            Main.notifyError(this.metadata.name, 'Install unix-utility-suite first.');
            this._buildMenu();
            return;
        }

        try {
            Gio.Subprocess.new([executable, option], Gio.SubprocessFlags.NONE);
        } catch (error) {
            console.error(error);
            Main.notifyError(this.metadata.name, `Could not launch ${TOOLKIT_COMMAND}.`);
        }
    }

    _registerShortcut() {
        this._unregisterShortcut();

        if (!this._settings.get_boolean('enable-shortcut'))
            return;

        try {
            Main.wm.addKeybinding(
                SHORTCUT_KEY,
                this._settings,
                Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
                Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW,
                () => this._launchToolkit('--launcher')
            );
            this._shortcutRegistered = true;
        } catch (error) {
            console.error(error);
        }
    }

    _unregisterShortcut() {
        if (!this._shortcutRegistered)
            return;

        Main.wm.removeKeybinding(SHORTCUT_KEY);
        this._shortcutRegistered = false;
    }

    _openInstallPage() {
        try {
            Gio.AppInfo.launch_default_for_uri(INSTALL_URL, null);
        } catch (error) {
            console.error(error);
            Main.notifyError(this.metadata.name, 'Could not open GitHub Releases.');
        }
    }

    _showInstallHelp() {
        Main.notify(
            this.metadata.name,
            'Install unix-utility-suite from the GitHub release, then enable this extension again.'
        );
    }
}
