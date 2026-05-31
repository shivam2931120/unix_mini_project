import Adw from 'gi://Adw';
import Gio from 'gi://Gio';

import {ExtensionPreferences, gettext as _} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const MENU_ROWS = [
    ['show-full-launcher', 'Open Full Toolkit', 'Show the full Linux Utility Toolkit launcher.'],
    ['show-system-info', 'System Info', 'Show operating system, CPU, RAM, and disk information.'],
    ['show-file-search', 'File Search', 'Search files from the top-bar menu.'],
    ['show-process-manager', 'Process Manager', 'Open the process viewer and termination tool.'],
    ['show-network-monitor', 'Network Monitor', 'Open the live network throughput monitor.'],
    ['show-scheduling-simulator', 'Scheduling Simulator', 'Open the process scheduling simulator.'],
];

export default class UnixToolkitPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        window._settings = settings;
        window.set_default_size(620, 560);

        const page = new Adw.PreferencesPage({
            title: _('General'),
            icon_name: 'preferences-system-symbolic',
        });
        window.add(page);

        const menuGroup = new Adw.PreferencesGroup({
            title: _('Menu Actions'),
            description: _('Choose which toolkit actions appear in the top-bar menu.'),
        });
        page.add(menuGroup);

        for (const [key, title, subtitle] of MENU_ROWS)
            menuGroup.add(this._switchRow(settings, key, _(title), _(subtitle)));

        const shortcutGroup = new Adw.PreferencesGroup({
            title: _('Keyboard Shortcut'),
        });
        page.add(shortcutGroup);

        shortcutGroup.add(this._switchRow(
            settings,
            'enable-shortcut',
            _('Enable Shortcut'),
            _('Open the full toolkit with Super+Alt+U.')
        ));

        const shortcutRow = new Adw.ActionRow({
            title: _('Shortcut'),
            subtitle: settings.get_strv('launcher-shortcut').join(', ') || _('Disabled'),
        });
        shortcutGroup.add(shortcutRow);

        const installGroup = new Adw.PreferencesGroup({
            title: _('Install Detection'),
        });
        page.add(installGroup);

        installGroup.add(new Adw.ActionRow({
            title: _('Missing toolkit behavior'),
            subtitle: _('If unix-toolkit is not installed, the menu shows install help and GitHub Releases.'),
        }));
    }

    _switchRow(settings, key, title, subtitle) {
        const row = new Adw.SwitchRow({title, subtitle});
        settings.bind(key, row, 'active', Gio.SettingsBindFlags.DEFAULT);
        return row;
    }
}
