import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Task UI is separated from calendar/time rendering; ClockContent owns the task state.
ColumnLayout {
    id: planner

    property var controller: null
    Layout.fillWidth: true
    spacing: Constants.sizeXs

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                text: controller.taskViewMode === "day"
                    ? "TASKS · " + Qt.formatDate(controller.selectedDate, "ddd, d MMM")
                    : "ALL TASKS"
                customSize: Constants.sizeSm
                font.weight: Font.Bold
                font.letterSpacing: 0.7
                color: Theme.fg
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            ThemedText {
                visible: controller.matchingTaskItems.length > 0
                text: controller.completedTaskCount + "/" +
                    controller.matchingTaskItems.length + " done"
                customSize: Constants.sizeXs
                color: Theme.muted
            }

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: controller.adding ? Theme.accent : Theme.bgSecondary

                ThemedText {
                    anchors.centerIn: parent
                    text: controller.adding ? "×" : "+"
                    font.bold: true
                    color: controller.adding ? Theme.bg : Theme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.setAdding(!controller.adding)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            Repeater {
                model: [
                    { "label": "All tasks", "value": "all" },
                    { "label": "Selected day", "value": "day" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 27
                    radius: Constants.sizeSm
                    color: controller.taskViewMode === modelData.value
                        ? Theme.accent : Theme.bgSecondary

                    ThemedText {
                        anchors.centerIn: parent
                        text: modelData.label
                        customSize: Constants.sizeXs + 1
                        font.bold: controller.taskViewMode === modelData.value
                        color: controller.taskViewMode === modelData.value
                            ? Theme.bg : Theme.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            controller.taskViewMode = modelData.value;
                            controller.showCompletedTasks = false;
                            controller.editingIndex = -1;
                        }
                    }
                }
            }
        }

        VeyraTextField {
            id: taskField

            visible: controller.adding
            Layout.fillWidth: true
            color: Theme.fg
            placeholderText: controller.taskViewMode === "day"
                ? "Task for " + Qt.formatDate(controller.selectedDate, "d MMM")
                : "New task (no due date)"
            placeholderTextColor: Theme.muted
            selectByMouse: true
            onAccepted: {
                controller.addTask(text);
                text = "";
            }
            Keys.onEscapePressed: controller.setAdding(false)

            background: Rectangle {
                radius: Constants.sizeSm
                color: Theme.isDark
                    ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                    : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                border.width: taskField.activeFocus ? 1.5 : 1
                border.color: taskField.activeFocus ? Theme.accent : (taskField.hovered ? Theme.muted : Theme.border)
            }
        }

        ThemedText {
            visible: controller.completedTaskCount > 0
            text: (controller.showCompletedTasks ? "▾ Hide completed (" : "▸ Completed (") +
                controller.completedTaskCount + ")"
            color: Theme.muted
            customSize: Constants.sizeXs + 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.showCompletedTasks = !controller.showCompletedTasks
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(taskCol.implicitHeight, 142)
            visible: controller.visibleTaskItems.length > 0
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: taskCol

                width: parent.width
                spacing: 3

                Repeater {
                    model: controller.visibleTaskItems

                    Rectangle {
                        readonly property int taskIndex: modelData.index
                        readonly property var taskData: modelData.task
                        readonly property bool isEditing:
                            controller.editingIndex === taskIndex

                        Layout.fillWidth: true
                        implicitHeight: isEditing ? 94 : 32
                        radius: Constants.sizeSm
                        color: isEditing ? Theme.bgSecondary :
                            (rowHover.hovered ? Theme.bgSecondary : "transparent")
                        clip: true

                        HoverHandler {
                            id: rowHover
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 3
                            visible: parent.isEditing

                            VeyraTextField {
                                id: editTaskNameField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                text: controller.editText
                                color: Theme.fg
                                font.pixelSize: 12
                                selectByMouse: true
                                placeholderText: "Task name"

                                onTextEdited: controller.editText = text
                                onAccepted: controller.commitEdit(taskIndex)

                                background: Rectangle {
                                    radius: Constants.sizeXs + 2
                                    color: Theme.isDark
                                        ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                                        : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                                    border.width: 1
                                    border.color: Theme.accent
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                VeyraTextField {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    text: controller.editDueDate
                                    color: Theme.fg
                                    font.pixelSize: 10
                                    selectByMouse: true
                                    placeholderText: "Due date YYYY-MM-DD"
                                    onTextEdited: controller.editDueDate = text
                                    onAccepted: controller.commitEdit(taskIndex)

                                    background: Rectangle {
                                        radius: Constants.sizeXs + 2
                                        color: Theme.isDark
                                            ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                                            : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                                        border.width: 1
                                        border.color: Theme.accent
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 61
                                    Layout.preferredHeight: 24
                                    radius: 6
                                    color: Theme.bg

                                    ThemedText {
                                        anchors.centerIn: parent
                                        text: controller.editPriority.toUpperCase()
                                        customSize: Constants.sizeXs
                                        font.bold: true
                                        color: controller.editPriority === "high"
                                            ? Theme.accent : Theme.fg
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controller.editPriority =
                                            controller.nextPriority(controller.editPriority)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Constants.sizeSm

                                ThemedText {
                                    Layout.fillWidth: true
                                    text: controller.taskEditError
                                    visible: controller.taskEditError !== ""
                                    color: Theme.accent
                                    customSize: Constants.sizeXs
                                    elide: Text.ElideRight
                                }

                                ThemedText {
                                    text: "Save"
                                    color: Theme.accent
                                    font.bold: true
                                    customSize: Constants.sizeXs + 1

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controller.commitEdit(taskIndex)
                                    }
                                }

                                ThemedText {
                                    text: "Cancel"
                                    color: Theme.muted
                                    customSize: Constants.sizeXs + 1

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            controller.editingIndex = -1;
                                            controller.taskEditError = "";
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Constants.sizeXs
                            anchors.rightMargin: Constants.sizeXs
                            spacing: Constants.sizeXs
                            visible: !parent.isEditing

                            Rectangle {
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                radius: 8
                                color: taskData.done ? Theme.accent : "transparent"
                                border.width: 1.5
                                border.color: taskData.done ? Theme.accent : Theme.muted

                                ThemedText {
                                    anchors.centerIn: parent
                                    text: taskData.done ? "✓" : ""
                                    customSize: 9
                                    color: Theme.bg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.toggleTask(taskIndex)
                                }
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: taskData.text
                                elide: Text.ElideRight
                                color: taskData.done ? Theme.muted : Theme.fg
                                font.strikeout: taskData.done

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.toggleTask(taskIndex)
                                }
                            }

                            ThemedText {
                                visible: Boolean(taskData.dueDate)
                                text: controller.formatDueDate(taskData.dueDate || "")
                                customSize: Constants.sizeXs
                                color: Theme.muted
                            }

                            ThemedText {
                                visible: taskData.priority !== "normal"
                                text: taskData.priority === "high" ? "!" : "↓"
                                font.bold: true
                                color: taskData.priority === "high"
                                    ? Theme.accent : Theme.muted

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.cycleTaskPriority(taskIndex)
                                }
                            }

                            ThemedText {
                                text: "✎"
                                color: Theme.muted

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.beginEdit(taskIndex)
                                }
                            }

                            ThemedText {
                                text: "×"
                                color: Theme.muted

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controller.removeTask(taskIndex)
                                }
                            }
                        }
                    }
                }
            }
        }

        ThemedText {
            visible: controller.visibleTaskItems.length === 0 && !controller.adding
            text: controller.matchingTaskItems.length > 0
                ? "All done! Open Completed to review."
                : (controller.taskViewMode === "day"
                    ? "Nothing scheduled for this day. Tap + to add one."
                    : "No tasks yet. Tap + to add one.")
            color: Theme.muted
            customSize: Constants.sizeXs + 1
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        RowLayout {
            visible: controller.lastDeletedTask !== null
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                Layout.fillWidth: true
                text: "Task deleted"
                color: Theme.muted
                customSize: Constants.sizeXs
            }

            ThemedText {
                text: "Undo"
                color: Theme.accent
                font.bold: true
                customSize: Constants.sizeXs + 1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.undoDelete()
                }
            }
        }

}
