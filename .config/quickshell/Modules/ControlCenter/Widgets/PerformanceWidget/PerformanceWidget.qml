import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows

Card {
    id: root

    property string powerProfile: SystemInfoService.systemProfile !== "" ? SystemInfoService.systemProfile : SystemInfoService.effectivePowerProfile
    property var profilesList: {
        let modes = ["power-saver", "balanced"];
        if (SystemInfoService.hasPerformanceProfile)
            modes.push("performance");
        return modes;
    }

    cardRadius: Constants.sizeMd
    useBorder: true
    borderColor: Theme.border
    backgroundColor: Theme.bgSecondary
    contentPadding: Constants.sizeSm

    RowLayout {
        anchors.fill: parent
        spacing: Constants.sizeSm

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: Constants.sizeSm
            color: Theme.bgAccent

            SvgIcon {
                anchors.centerIn: parent
                icon: "rocket"
                iconSize: 18
                iconColor: Theme.accent
            }
        }

        ThemedSelect {
            id: profileSelect
            Layout.fillWidth: true
            label: "Power profile"
            description: {
                const p = root.powerProfile;
                if (p === "power-saver") return "Extending battery life";
                if (p === "balanced") return "Balanced performance";
                if (p === "performance") return "Maximum performance";
                return "Choose performance mode";
            }
            customSize: Constants.sizeSm
            comboWidth: 132
            model: root.profilesList
            textMap: ({
                "power-saver": "Power Saver",
                "balanced": "Balanced",
                "performance": "Performance"
            })

            Component.onCompleted: syncProfileIndex()

            function syncProfileIndex() {
                const current = SystemInfoService.systemProfile !== ""
                    ? SystemInfoService.systemProfile
                    : SystemInfoService.effectivePowerProfile;
                const index = root.profilesList.indexOf(current);
                profileSelect.currentIndex = index >= 0 ? index : 0;
            }

            onActivated: (index) => {
                if (index >= 0 && index < root.profilesList.length)
                    SystemInfoService.applyProfile(root.profilesList[index]);
            }

            Connections {
                target: SystemInfoService
                function onPowerProfileChanged() { profileSelect.syncProfileIndex(); }
                function onSystemProfileChanged() { profileSelect.syncProfileIndex(); }
            }
        }
    }
}
