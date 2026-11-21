import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Core
import qs.Core.Services

Item {
    id: root

    property alias server: notificationServer
    property alias activeList: activeListModel
    property alias historyList: historyListModel
    // DND combines the persistent manual preference, scheduled quiet hours, and Game Mode.
    property bool quietHoursActive: false
    readonly property bool mediaDndActive: SettingsService.notificationDndWhileMediaPlaying && MprisService.isPlaying
    property bool dndEnabled: SettingsService.notificationsDndEnabled || DisplayProfileService.gameModeActive || root.quietHoursActive || root.mediaDndActive
    property int unreadCount: historyListModel.count
    // Suggested apps are available immediately; apps seen in notifications are added dynamically.
    property var knownAppNames: ["Discord", "Firefox", "Heroic", "Slack", "Spotify", "Steam", "Telegram", "VSCodium", "WhatsApp"]
    property var notificationObjects: ({
    })
    property var notificationGroups: ({
    })
    property var groupRepresentationIds: ({
    })

    function appAllowsPopups(appName) {
        return SettingsService.isNotificationAppEnabled(appName);
    }

    function canShowPopup(appName, urgency) {
        return SettingsService.notificationsPopupsEnabled
            && root.appAllowsPopups(appName)
            && (!root.dndEnabled || (SettingsService.notificationsCriticalDuringDnd && urgency === 2));
    }

    function refreshKnownAppsFromRules() {
        const rules = SettingsService.notificationAppPopupRules || {};
        const apps = (root.knownAppNames || []).slice();
        for (const key in rules) {
            if (!Object.prototype.hasOwnProperty.call(rules, key))
                continue;
            let present = false;
            for (let i = 0; i < apps.length; i++) {
                if (String(apps[i]).toLowerCase() === String(key).toLowerCase()) {
                    present = true;
                    break;
                }
            }
            if (!present && String(key).trim() !== "")
                apps.push(String(key));
        }
        apps.sort((a, b) => String(a).localeCompare(String(b)));
        root.knownAppNames = apps;
    }

    function rememberAppName(appName) {
        const name = String(appName || "").trim();
        const key = name.toLowerCase();
        if (name === "" || key === "system" || key === "unknown" || key === "veyra")
            return;
        const apps = (root.knownAppNames || []).slice();
        for (let i = 0; i < apps.length; i++) {
            if (String(apps[i]).toLowerCase() === key)
                return;
        }
        apps.push(name);
        apps.sort((a, b) => String(a).localeCompare(String(b)));
        root.knownAppNames = apps;
    }

    function updateQuietHours() {
        if (!SettingsService.notificationQuietHoursEnabled) {
            root.quietHoursActive = false;
            return;
        }
        const now = new Date();
        const current = now.getHours() * 60 + now.getMinutes();
        const start = Math.max(0, Math.min(23, Number(SettingsService.notificationQuietHoursStartHour))) * 60;
        const end = Math.max(0, Math.min(23, Number(SettingsService.notificationQuietHoursEndHour))) * 60;
        let active = false;
        if (start !== end)
            active = start < end ? (current >= start && current < end) : (current >= start || current < end);
        root.quietHoursActive = active;
    }

    function pruneActiveNotifications() {
        let maxCount = 1;
        while (activeListModel.count > maxCount) {
            let oldItem = activeListModel.get(maxCount);
            if (oldItem && oldItem.notifData)
                oldItem.notifData.popup = false;

            activeListModel.remove(maxCount);
        }
    }

    function pruneForIslandMode() {
        pruneActiveNotifications();
    }

    function notify(summary, body, icon = "", appName = "System", urgency = NotificationUrgency.Normal) {
        let timestamp = new Date().getTime();
        root.rememberAppName(appName);
        let canPopup = root.canShowPopup(appName, urgency);
        let nd = notificationDataComponent.createObject(root, {
            "notificationId": timestamp.toString(),
            "summary": summary,
            "body": body,
            "appName": appName,
            "appIcon": icon,
            "urgency": urgency,
            "timestamp": timestamp,
            "isDnd": root.dndEnabled,
            "popup": canPopup
        });
        notificationObjects[timestamp] = nd;
        historyListModel.insert(0, {
            "id": timestamp,
            "notifData": nd
        });
        while (historyListModel.count > SettingsService.notificationHistoryLimit)
            removeHistoryItem(historyListModel.count - 1);
        if (canPopup) {
            activeListModel.insert(0, {
                "id": timestamp,
                "notifData": nd
            });
            pruneActiveNotifications();
        }
        return timestamp;
    }

    function dismissNotification(id) {
        let nd = notificationObjects[id];
        if (nd)
            nd.close();

        removeNotification(id);
    }

    function getGroupKey(notification) {
        if (!SettingsService.notificationGroupingEnabled || !root.appAllowsPopups(notification.appName))
            return "";

        let appsToGroup = ["whatsapp", "telegram", "discord", "slack"];
        let app = (notification.appName || "").toLowerCase();
        for (let i = 0; i < appsToGroup.length; i++) {
            if (app.includes(appsToGroup[i]))
                return appsToGroup[i];

        }
        return "";
    }

    function copyObject(obj) {
        let copy = {
        };
        for (let k in obj) {
            copy[k] = obj[k];
        }
        return copy;
    }

    function removeNotification(id) {
        for (let groupKey in groupRepresentationIds) {
            if (groupRepresentationIds[groupKey] == id) {
                let groups = copyObject(notificationGroups);
                groups[groupKey] = [];
                notificationGroups = groups;
                let reps = copyObject(groupRepresentationIds);
                delete reps[groupKey];
                groupRepresentationIds = reps;
                break;
            }
        }
        if (notificationObjects[id]) {
            notificationObjects[id].destroy(1000);
            delete notificationObjects[id];
        }
        for (var i = 0; i < activeListModel.count; i++) {
            if (activeListModel.get(i).id == id) {
                activeListModel.remove(i);
                break;
            }
        }
        for (var j = 0; j < historyListModel.count; j++) {
            if (historyListModel.get(j).id == id) {
                historyListModel.remove(j);
                break;
            }
        }
    }

    function clearHistory() {
        notificationGroups = {
        };
        groupRepresentationIds = {
        };
        for (let id in notificationObjects) {
            notificationObjects[id].destroy();
        }
        notificationObjects = {
        };
        historyListModel.clear();
        activeListModel.clear();
    }

    function removeHistoryItem(index) {
        if (index >= 0 && index < historyListModel.count) {
            let id = historyListModel.get(index).id;
            removeNotification(id);
        }
    }

    // Transient hardware/workspace feedback belongs to IslandEventService.
    // Drop legacy notify-send copies of those events before they enter history
    // or the popup stack. Keep recording errors and unrelated app notices.
    // Only when the island pill is actually the active OSD renderer —
    // in convex or gaming mode the event fires but nothing displays it.
    function isIslandOwnedOsd(notification) {
        if (!notification)
            return false;

        if (!SettingsService.barIslandMode || DisplayProfileService.gameModeActive)
            return false;

        const summary = String(notification.summary || "").trim().toLowerCase().replace(/\s+/g, " ");
        const app = String(notification.appName || "").trim().toLowerCase();
        const legacySystemSender = app === "" || app === "system" || app === "notify-send" || app.includes("notify-send");
        if (!legacySystemSender)
            return false;

        const exactSummaries = [
            "volume", "audio volume", "brightness", "screen brightness",
            "microphone", "microphone muted", "workspace",
            "recording", "recording finished", "recording ended",
            "screen recording", "screen recording started", "screen recording stopped",
            "screen recording paused", "screen recording resumed"
        ];
        return exactSummaries.includes(summary);
    }

    function handleNotificationUpdate(notification) {
        if (root.isIslandOwnedOsd(notification)) {
            notification.dismiss();
            return;
        }
        root.rememberAppName(notification.appName);
        let groupKey = getGroupKey(notification);
        if (!groupKey) {
            root.updateNotificationData(notification);
            return ;
        }
        let groups = copyObject(notificationGroups);
        if (!groups[groupKey])
            groups[groupKey] = [];

        let msgIndex = -1;
        for (let i = 0; i < groups[groupKey].length; i++) {
            if (groups[groupKey][i].id == notification.id) {
                msgIndex = i;
                break;
            }
        }
        let msgData = {
            "id": notification.id,
            "summary": notification.summary ? notification.summary : "",
            "body": notification.body ? notification.body : "",
            "timestamp": new Date().getTime()
        };
        if (msgIndex >= 0)
            groups[groupKey][msgIndex] = msgData;
        else
            groups[groupKey].push(msgData);
        notificationGroups = groups;
        let reps = copyObject(groupRepresentationIds);
        let repId = reps[groupKey];
        if (!repId || repId == notification.id) {
            reps[groupKey] = notification.id;
            groupRepresentationIds = reps;
            root.updateNotificationData(notification);
        } else {
            if (!notification.alreadyDismissed) {
                notification.alreadyDismissed = true;
                notification.dismiss();
            }
            let repData = notificationObjects[repId];
            if (repData) {
                let displayNames = {
                    "whatsapp": "WhatsApp",
                    "telegram": "Telegram",
                    "discord": "Discord",
                    "slack": "Slack"
                };
                let displayName = displayNames[groupKey] || repData.appName;
                let combinedBody = groups[groupKey].map((m) => {
                    return (m.summary ? m.summary + ": " : "") + m.body;
                }).join("\n");
                let combinedSummary = displayName + " (" + groups[groupKey].length + ")";
                repData.summary = combinedSummary;
                repData.body = combinedBody;
                repData.appName = displayName;
                repData.timestamp = new Date().getTime();
                let historyIndex = -1;
                for (let i = 0; i < historyListModel.count; i++) {
                    if (historyListModel.get(i).id == repId) {
                        historyIndex = i;
                        break;
                    }
                }
                if (historyIndex > 0)
                    historyListModel.move(historyIndex, 0, 1);

                if (root.canShowPopup(repData.appName, repData.urgency)) {
                    let activeIndex = -1;
                    for (let i = 0; i < activeListModel.count; i++) {
                        if (activeListModel.get(i).id == repId) {
                            activeIndex = i;
                            break;
                        }
                    }
                    repData.popup = true;
                    repData.startProgress();
                    if (activeIndex > 0)
                        activeListModel.move(activeIndex, 0, 1);
                    else if (activeIndex === -1)
                        activeListModel.insert(0, {
                        "id": repId,
                        "notifData": repData
                    });
                    pruneActiveNotifications();
                }
            }
        }
    }

    function updateNotificationData(notification) {
        let nd = notificationObjects[notification.id];
        if (!nd) {
            let canPopup = root.canShowPopup(notification.appName, notification.urgency);
            nd = notificationDataComponent.createObject(root, {
                "notification": notification,
                "isDnd": root.dndEnabled,
                "popup": canPopup
            });
            notificationObjects[notification.id] = nd;
        } else {
            if (nd.notification !== notification) {
                nd.notification = notification;
                nd.summary = notification.summary;
                nd.body = notification.body;
                nd.appIcon = notification.appIcon;
                nd.appName = notification.appName;
                nd.image = notification.image;
                nd.urgency = notification.urgency;
            }
            if (root.canShowPopup(nd.appName, nd.urgency) && !nd.closed) {
                nd.popup = true;
                nd.startProgress();
            }
        }
        if (!nd.isTransient) {
            let historyUpdated = false;
            for (let i = 0; i < historyListModel.count; i++) {
                if (historyListModel.get(i).id == notification.id) {
                    if (i > 0)
                        historyListModel.move(i, 0, 1);

                    historyUpdated = true;
                    break;
                }
            }
            if (!historyUpdated)
                historyListModel.insert(0, {
                "id": notification.id,
                "notifData": nd
            });

        }
        if (root.canShowPopup(nd.appName, nd.urgency) && nd.popup) {
            let activeUpdated = false;
            for (let i = 0; i < activeListModel.count; i++) {
                if (activeListModel.get(i).id == notification.id) {
                    if (i > 0)
                        activeListModel.move(i, 0, 1);

                    activeUpdated = true;
                    break;
                }
            }
            if (!activeUpdated)
                activeListModel.insert(0, {
                "id": notification.id,
                "notifData": nd
            });

            pruneActiveNotifications();
        }
        while (historyListModel.count > SettingsService.notificationHistoryLimit) removeHistoryItem(historyListModel.count - 1)
    }

    function applyDndPolicy() {
        for (let id in notificationObjects) {
            let nd = notificationObjects[id];
            nd.isDnd = root.dndEnabled;
            if (!root.canShowPopup(nd.appName, nd.urgency)) {
                nd.popup = false;
                if (nd.progressAnim && nd.progressAnim.running)
                    nd.progressAnim.stop();
            }
        }
        for (let i = activeListModel.count - 1; i >= 0; i--) {
            let nd = activeListModel.get(i).notifData;
            if (!nd || !root.canShowPopup(nd.appName, nd.urgency))
                activeListModel.remove(i);
        }
    }

    onDndEnabledChanged: applyDndPolicy()

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateQuietHours()
    }

    Component {
        id: notificationDataComponent

        NotificationData {
            notificationService: root
        }

    }

    Connections {
        function onBarIslandModeChanged() {
            root.pruneActiveNotifications();
        }

        function onNotificationsPopupsEnabledChanged() {
            if (!SettingsService.notificationsPopupsEnabled) {
                for (let id in root.notificationObjects) {
                    let nd = root.notificationObjects[id];
                    nd.popup = false;
                    if (nd.progressAnim && nd.progressAnim.running)
                        nd.progressAnim.stop();
                }
                activeListModel.clear();
            }
        }

        function onNotificationsCriticalDuringDndChanged() {
            root.applyDndPolicy();
        }

        function onNotificationAppPopupRulesChanged() {
            root.refreshKnownAppsFromRules();
            root.applyDndPolicy();
        }

        function onNotificationQuietHoursEnabledChanged() {
            root.updateQuietHours();
            root.applyDndPolicy();
        }

        function onNotificationQuietHoursStartHourChanged() {
            root.updateQuietHours();
            root.applyDndPolicy();
        }

        function onNotificationQuietHoursEndHourChanged() {
            root.updateQuietHours();
            root.applyDndPolicy();
        }

        function onNotificationHistoryLimitChanged() {
            while (historyListModel.count > SettingsService.notificationHistoryLimit)
                root.removeHistoryItem(historyListModel.count - 1);
        }

        target: SettingsService
    }

    Connections {
        property string _prevStatus: ""
        property int _prevLevel: -1
        property bool _notifiedFull: false

        function onBatteryStatusChanged() {
            let status = SystemInfoService.batteryStatus;
            let level = SystemInfoService.batteryLevel;
            if (!SystemInfoService.hasBattery || status === "" || status === _prevStatus)
                return ;

            if (_prevStatus !== "") {
                let summary = "Battery";
                let body = "";
                if (status === "Charging") {
                    if (_prevStatus === "Discharging") {
                        summary = "Battery";
                        body = "Charger connected";
                    }
                } else if (status === "Discharging") {
                    if (_prevStatus === "Charging" || _prevStatus === "Full" || _prevStatus === "Not charging") {
                        summary = "Battery";
                        body = "Charger disconnected";
                    }
                } else if (status === "Full" || status === "Not charging") {
                    if (!_notifiedFull && status === "Full" && level >= 95) {
                        summary = "Battery";
                        body = "Battery fully charged";
                        _notifiedFull = true;
                    }
                }
                if (body !== "")
                    root.notify(summary, body);

            }
            _prevStatus = status;
        }

        function onBatteryLevelChanged() {
            let status = SystemInfoService.batteryStatus;
            let level = SystemInfoService.batteryLevel;
            if (!SystemInfoService.hasBattery || level <= 0 || level === _prevLevel)
                return ;

            if (status === "Discharging" && level < 95)
                _notifiedFull = false;

            if (_prevLevel !== -1 && status === "Discharging") {
                let threshold = 0;
                if (level <= 5 && _prevLevel > 5)
                    threshold = 5;
                else if (level <= 10 && _prevLevel > 10)
                    threshold = 10;
                else if (level <= 20 && _prevLevel > 20)
                    threshold = 20;
                if (threshold > 0)
                    root.notify("Low Battery", "Battery level: " + level + "%", "", "System", NotificationUrgency.Critical);

            }
            _prevLevel = level;
        }

        target: SystemInfoService
    }

    Connections {
        property real _start: Date.now()
        property string _prevProfile: ""

        function onSystemProfileChanged() {
            let p = SystemInfoService.systemProfile;
            if (p === "" || p === _prevProfile)
                return ;

            let first = (_prevProfile === "");
            _prevProfile = p;
            if (first || (Date.now() - _start) < 8000)
                return ;

            let names = {
                "performance": "Performance",
                "balanced": "Balanced",
                "power-saver": "Power saver"
            };
            root.notify("Power Profile", (names[p] || p) + " mode active");
        }

        target: SystemInfoService
    }

    ListModel {
        id: activeListModel
    }

    ListModel {
        id: historyListModel
    }

    NotificationServer {
        id: notificationServer

        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        onNotification: (notification) => {
            if (notification.tracked)
                return ;

            notification.tracked = true;
            notification.closed.connect((reason) => {
                let nd = root.notificationObjects[notification.id];
                if (nd && nd.notification !== notification)
                    return ;

                if (nd)
                    nd.popup = false;

            });
            notification.summaryChanged.connect(() => {
                root.handleNotificationUpdate(notification);
            });
            notification.bodyChanged.connect(() => {
                root.handleNotificationUpdate(notification);
            });
            root.handleNotificationUpdate(notification);
        }
    }

}
