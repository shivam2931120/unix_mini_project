const cp = require('child_process');
const vscode = require('vscode');

function configuredExecutable() {
    return vscode.workspace
        .getConfiguration('unixUtilitySuite')
        .get('executablePath', 'unix-toolkit');
}

function shellQuote(value) {
    return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function checkInstall(executable) {
    return new Promise((resolve) => {
        const command = `command -v ${shellQuote(executable)}`;
        cp.exec(command, {shell: '/bin/sh'}, (error, stdout) => {
            if (error) {
                resolve(null);
                return;
            }

            resolve(stdout.trim() || executable);
        });
    });
}

async function launchToolkit() {
    const executable = configuredExecutable();
    const resolved = await checkInstall(executable);

    if (!resolved) {
        vscode.window.showErrorMessage(`Could not find ${executable}. Install the unix-utility-suite .deb package first.`);
        return;
    }

    const child = cp.spawn(resolved, {
        detached: true,
        stdio: 'ignore',
    });

    child.on('error', (error) => {
        vscode.window.showErrorMessage(`Could not launch Unix Utility Suite: ${error.message}`);
    });

    child.unref();
}

async function showInstallStatus() {
    const executable = configuredExecutable();
    const resolved = await checkInstall(executable);

    if (resolved) {
        vscode.window.showInformationMessage(`Unix Utility Suite is installed: ${resolved}`);
    } else {
        vscode.window.showWarningMessage(`Unix Utility Suite is not installed. Expected command: ${executable}`);
    }
}

function activate(context) {
    context.subscriptions.push(
        vscode.commands.registerCommand('unixUtilitySuite.launch', launchToolkit),
        vscode.commands.registerCommand('unixUtilitySuite.checkInstall', showInstallStatus),
    );
}

function deactivate() {}

module.exports = {
    activate,
    deactivate,
};
