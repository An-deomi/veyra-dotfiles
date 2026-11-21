import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core.Services

Item {
    id: root

    property bool authenticating: false
    property bool authFailed: false
    property bool unlocking: false
    property string pendingPassword: ""

    signal authSucceeded()
    signal lockRequested()

    function reset() {
        root.authFailed = false;
        root.authenticating = false;
        root.unlocking = false;
    }

    function submitPassword(pwd) {
        if (root.authenticating)
            return ;

        authProc.running = false;
        root.authenticating = true;
        root.authFailed = false;
        root.pendingPassword = pwd;
        authProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/auth.py"];
        authProc.running = true;
        authTimeout.restart();
    }


    IpcHandler {
        // IPC may only ever lock the session. Unlocking always requires an
        // interactively typed password verified by PAM.
        function toggle() {
            root.lockRequested();
        }

        function lock() {
            root.lockRequested();
        }

        target: "lockScreen"
    }


    Timer {
        id: authTimeout

        interval: 10000
        repeat: false
        onTriggered: {
            if (!root.authenticating)
                return ;

            authProc.running = false;
            root.authenticating = false;
            root.authFailed = true;
        }
    }


    Process {
        id: authProc

        stdinEnabled: true
        onStarted: {
            authProc.write(root.pendingPassword + "\n");
            root.pendingPassword = "";
        }
        onExited: function(exitCode) {
            authTimeout.stop();
            if (!root.authenticating)
                return ;

            root.authenticating = false;
            if (exitCode === 0) {
                root.unlocking = true;
                root.authSucceeded();
            } else {
                root.authFailed = true;
            }
        }
    }

}
