/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020-2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem

ColumnLayout {
    id: root

    required property var model
    required property int index
    required property /*QModelIndex*/ var submodelIndex
    required property int appPid
    required property string display
    required property bool isMinimized
    required property bool isOnAllVirtualDesktops
    required property /*list<var>*/ var virtualDesktops // Can't use list<var> because of QTBUG-127600
    required property list<string> activities
    required property bool isReadyForPainting

    property rect winGeometry: Qt.rect(0, 0, 0, 0)
    property bool hasTrackInATitle: false
    property int orientation: ListView.Vertical // vertical for compact single-window tooltips
    readonly property var pulseAudio: toolTipDelegate.parentTask ? toolTipDelegate.parentTask.pulseAudio : null

    // Window aspect ratio computation using intrinsic window/stream dimensions
    readonly property real windowAspectRatio: {
        const pw = pipeWireLoader.item;
        if (pw && pw.streamSize && pw.streamSize.height > 0 && pw.streamSize.width > 0) {
            return pw.streamSize.width / pw.streamSize.height;
        }
        const geom = (root.winGeometry && root.winGeometry.height > 0)
            ? root.winGeometry
            : (root.model?.Geometry ?? Qt.rect(0, 0, 0, 0));
        if (geom && geom.height > 0 && geom.width > 0) {
            return geom.width / geom.height;
        }
        return 16 / 9;
    }

    readonly property real maxPreviewWidth: toolTipDelegate.tooltipInstanceMaximumWidth
    readonly property real maxPreviewHeight: Math.round(Kirigami.Units.gridUnit * 8.5)
    readonly property real minPreviewWidth: Math.round(Kirigami.Units.gridUnit * 8.5)
    readonly property real minPreviewHeight: Math.round(Kirigami.Units.gridUnit * 5)

    readonly property real previewWidth: {
        if (!toolTipDelegate.isWin || !Plasmoid.configuration.showToolTips) {
            return toolTipDelegate.tooltipInstanceMaximumWidth;
        }
        const ar = windowAspectRatio;
        const maxAr = maxPreviewWidth / maxPreviewHeight;
        if (ar >= maxAr) {
            return maxPreviewWidth;
        } else {
            return Math.max(minPreviewWidth, Math.min(maxPreviewWidth, Math.round(maxPreviewHeight * ar)));
        }
    }

    readonly property real previewHeight: {
        if (!toolTipDelegate.isWin || !Plasmoid.configuration.showToolTips) {
            return 0;
        }
        const ar = windowAspectRatio;
        const maxAr = maxPreviewWidth / maxPreviewHeight;
        if (ar >= maxAr) {
            return Math.max(minPreviewHeight, Math.round(maxPreviewWidth / ar));
        } else {
            return maxPreviewHeight;
        }
    }

    readonly property string windowTitleText: {
        let text = "";
        if (display && display.length > 0) {
            text = display;
        } else if (root.title && root.title.length > 0 && root.title !== "—") {
            text = root.title;
        } else {
            text = toolTipDelegate.appName;
        }

        const sub = toolTipDelegate.isWin ? root.generateSubText() : "";
        if (sub && sub.length > 0 && sub !== toolTipDelegate.appName) {
            return `${text} (${sub})`;
        }
        return text;
    }

    Layout.preferredWidth: previewWidth
    Layout.maximumWidth: maxPreviewWidth
    implicitWidth: previewWidth

    // HACK: Avoid blank space in the tooltip after closing a window
    ListView.onPooled: width = height = 0
    ListView.onReused: width = height = undefined

    // Lots of spacing with no thumbnails looks bad
    spacing: Plasmoid.configuration.showToolTips ? Kirigami.Units.smallSpacing : 0

    // text labels + close button
    Item {
        id: headerItem
        implicitHeight: header.height
        implicitWidth: root.previewWidth
        Layout.fillWidth: true
        Layout.preferredWidth: root.previewWidth
        Layout.maximumWidth: root.previewWidth
        Layout.minimumWidth: root.minPreviewWidth
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        // match margins of DefaultToolTip.qml in plasma-framework
        Layout.margins: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips ? 0 : Kirigami.Units.gridUnit / 2

        RowLayout {
            id: header
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            // Window icon
            Kirigami.Icon {
                id: windowIcon
                visible: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignVCenter
                source: toolTipDelegate.icon
            }

            // Single line window title (or app name for launchers)
            PlasmaComponents3.Label {
                id: winTitle
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                text: toolTipDelegate.isWin ? root.windowTitleText : (toolTipDelegate.genericName ? `${toolTipDelegate.appName} — ${toolTipDelegate.genericName}` : toolTipDelegate.appName)
                font.bold: toolTipDelegate.isGroup && toolTipDelegate.parentTask.model.IsActive && root.index == tasksModel.activeTask.row
                font.weight: toolTipDelegate.isWin ? Font.Normal : Font.DemiBold
                color: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                opacity: (headerHoverHandler.visible && headerHoverHighlight.pressed) ? 1.0 : 0.90
                textFormat: Text.PlainText
            }

            // Count badge
            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: closeButton.height
                Layout.preferredWidth: closeButton.width
                visible: root.index === 0 && toolTipDelegate.smartLauncherCountVisible

                Kirigami.Badge {
                    anchors.centerIn: parent
                    text: toolTipDelegate.smartLauncherCount
                }
            }

            // Close button
            PlasmaComponents3.ToolButton {
                id: closeButton
                visible: toolTipDelegate.isWin
                Layout.alignment: Qt.AlignVCenter
                icon.name: "window-close"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                onClicked: {
                    tasks.cancelHighlightWindows();
                    tasksModel.requestClose(root.submodelIndex);
                }
                PlasmaComponents3.ToolTip.text: i18nc("@info:tooltip Close this window", "Close window")
                PlasmaComponents3.ToolTip.visible: root.visible && hovered
                PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // make the header clickable if image tooltips are disabled (and thus there is no other clickable area that activates the window)
        // headerHoverHandler has to be unloaded after the instance is pooled in order to avoid getting the old containsMouse status when the same instance is reused, so put it in a Loader.
        Loader {
            id: headerHoverHandler
            active: (root.index !== -1) && !Plasmoid.configuration.showToolTips
            z: -2
            anchors.fill: headerItem
            anchors.margins: -headerItem.Layout.margins
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }
        }

        // There's no PlasmaComponents3 version
        PlasmaExtras.Highlight {
            id: headerHoverHighlight
            anchors.fill: headerHoverHandler
            z: -1
            visible: (headerHoverHandler.item as MouseArea)?.containsMouse ?? false
            pressed: (headerHoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }
    }

    // thumbnail container
    Item {
        id: thumbnailSourceItem

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.previewWidth
        Layout.preferredHeight: root.previewHeight
        width: root.previewWidth
        height: root.previewHeight

        clip: true
        visible: Plasmoid.configuration.showToolTips && toolTipDelegate.isWin

        readonly property /*undefined|WId where WId = int|string*/ var winId:
            toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined

        // Background card scaled to fit the exact aspect ratio of the window
        Rectangle {
            id: previewBackgroundCard
            anchors.fill: parent
            radius: 4
            color: (hoverHandler.item as MouseArea)?.containsMouse
                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.20)
                : Qt.rgba(0, 0, 0, 0.35)
            border.color: (hoverHandler.item as MouseArea)?.containsMouse
                ? Kirigami.Theme.highlightColor
                : Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            z: -1

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
            Behavior on border.color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        // There's no PlasmaComponents3 version
        PlasmaExtras.Highlight {
            anchors.fill: previewBackgroundCard
            visible: (hoverHandler.item as MouseArea)?.containsMouse ?? false
            pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }

        Loader {
            id: thumbnailLoader
            active: !toolTipDelegate.isLauncher
                && (Number.isInteger(thumbnailSourceItem.winId) || pipeWireLoader.item
                && !(pipeWireLoader.item as PipeWireThumbnail).hasThumbnail)
                && root.index !== -1 // Avoid loading when the instance is going to be destroyed
            asynchronous: true
            visible: active
            anchors.fill: hoverHandler
            // Indent a little bit so that neither the thumbnail nor the drop
            // shadow can cover up the highlight
            anchors.margins: Kirigami.Units.smallSpacing * 2

            sourceComponent: root.isMinimized || pipeWireLoader.active ? iconItem : x11Thumbnail

            Component {
                id: x11Thumbnail

                PlasmaCore.WindowThumbnail {
                    winId: thumbnailSourceItem.winId
                }
            }

            // when minimized, we don't have a preview on X11, so show the icon
            Component {
                id: iconItem

                Kirigami.Icon {
                    id: realIconItem
                    source: toolTipDelegate.icon
                    animated: false
                    visible: valid
                    opacity: pipeWireLoader.active ? 0 : 1

                    SequentialAnimation {
                        running: true

                        PauseAnimation {
                            duration: Kirigami.Units.humanMoment
                        }

                        NumberAnimation {
                            id: showAnimation
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                            property: "opacity"
                            target: realIconItem
                            to: 1
                        }
                    }

                }
            }
        }

        Loader {
            id: pipeWireLoader
            anchors.fill: hoverHandler
            // Indent a little bit so that neither the thumbnail nor the drop
            // shadow can cover up the highlight
            anchors.margins: thumbnailLoader.anchors.margins

            active: Plasmoid.configuration.showToolTips
                && !toolTipDelegate.isLauncher
                && KWindowSystem.isPlatformWayland
                && toolTipDelegate.isReadyForPainting
                && root.index !== -1
            asynchronous: true
            //In a loader since we might not have PipeWire available yet (WITH_PIPEWIRE could be undefined in plasma-workspace/libtaskmanager/declarative/taskmanagerplugin.cpp)
            source: "PipeWireThumbnail.qml"
        }

        Loader {
            active: Plasmoid.configuration.showToolTips
                && (((pipeWireLoader.item as PipeWireThumbnail)?.hasThumbnail ?? false) || (thumbnailLoader.status === Loader.Ready && !root.isMinimized))
            asynchronous: true
            visible: active
            anchors.fill: pipeWireLoader.active ? pipeWireLoader : thumbnailLoader

            sourceComponent: GE.DropShadow {
                horizontalOffset: 0
                verticalOffset: 3
                radius: 8
                samples: Math.round(radius * 1.5)
                color: "Black"
                source: pipeWireLoader.active ? pipeWireLoader.item : thumbnailLoader.item
            }
        }

        // hoverHandler has to be unloaded after the instance is pooled in order to avoid getting the old containsMouse status when the same instance is reused, so put it in a Loader.
        Loader {
            id: hoverHandler
            active: root.index !== -1
            anchors.fill: parent
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
            }
        }
    }

    // Player controls row, load on demand so group tooltips could be loaded faster
    Loader {
        id: playerController
        // Only load for one entry, as the controls only apply to one window.
        // If this is changed in the future, test for index != -1 to avoid loading
        // when the instance is going to be destroyed
        active: (toolTipDelegate.parentTask?.tooltipControlsEnabled
             && toolTipDelegate.playerData
             && (root.hasTrackInATitle || root.index == 0)) ?? false

        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: root.previewWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins

        source: "PlayerController.qml"
    }

    // Volume controls
    Loader {
        id: volumeControls
        active: toolTipDelegate.parentTask !== null
             && pulseAudio.item !== null
             && toolTipDelegate.parentTask.tooltipControlsEnabled
             && toolTipDelegate.parentTask.hasAudioStream
             // Only load for one entry, as the controls only apply to one window.
             // If this is changed in the future, test for index != -1 to avoid loading
             // when the instance is going to be destroyed
             && (root.hasTrackInATitle || root.index == 0)
        asynchronous: true
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: root.previewWidth
        Layout.leftMargin: headerItem.Layout.margins
        Layout.rightMargin: headerItem.Layout.margins
        sourceComponent: RowLayout {
            PlasmaComponents3.ToolButton { // Mute button
                id: muteButton
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                icon.name: {
                    let finalIcon = ""

                    if (checked) {
                        finalIcon = "audio-volume-muted"
                    } else if (slider.displayValue <= 25) {
                        finalIcon = "audio-volume-low"
                    } else if (slider.displayValue <= 75) {
                        finalIcon = "audio-volume-medium"
                    } else {
                        finalIcon = "audio-volume-high"
                    }

                    if (mirrored) {
                        finalIcon = finalIcon + "-rtl"
                    }

                    return finalIcon
                }
                onClicked: toolTipDelegate.parentTask.toggleMuted()
                checked: toolTipDelegate.parentTask.muted

                PlasmaComponents3.ToolTip {
                    text: muteButton.checked
                        ? i18nc("button to unmute app", "Unmute %1", toolTipDelegate.parentTask.appName)
                        : i18nc("button to mute app", "Mute %1", toolTipDelegate.parentTask.appName)
                }
            }

            PlasmaComponents3.Slider {
                id: slider

                readonly property int displayValue: Math.round(value / to * 100)
                readonly property int loudestVolume: toolTipDelegate.parentTask.audioStreams
                    .reduce((loudestVolume, stream) => Math.max(loudestVolume, stream.volume), 0)

                Layout.fillWidth: true
                from: pulseAudio.item.minimalVolume
                to: pulseAudio.item.normalVolume
                value: loudestVolume
                stepSize: to / 100
                opacity: toolTipDelegate.parentTask.muted ? 0.5 : 1

                Accessible.name: i18nc("Accessibility data on volume slider", "Adjust volume for %1", toolTipDelegate.parentTask.appName)

                onMoved: toolTipDelegate.parentTask.audioStreams.forEach((stream) => {
                    let v = Math.max(from, value)
                    if (v > 0 && loudestVolume > 0) { // prevent divide by 0
                        // adjust volume relative to the loudest stream
                        v = Math.min(Math.round(stream.volume / loudestVolume * v), to)
                    }
                    stream.model.Volume = v
                    stream.model.Muted = v === 0
                })
            }
            PlasmaComponents3.Label { // percent label
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumWidth: percentMetrics.advanceWidth
                horizontalAlignment: Qt.AlignRight
                text: i18nc("volume percentage", "%1%", slider.displayValue)
                textFormat: Text.PlainText
                TextMetrics {
                    id: percentMetrics
                    text: i18nc("only used for sizing, should be widest possible string", "100%")
                }
            }
        }
    }

    function generateSubText(): string {
        const subTextEntries = [];

        if (!Plasmoid.configuration.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
            if (!isOnAllVirtualDesktops && virtualDesktops.length > 0) {
                const virtualDesktopNameList = virtualDesktops.map(virtualDesktop => {
                    const index = virtualDesktopInfo.desktopIds.indexOf(virtualDesktop);
                    return virtualDesktopInfo.desktopNames[index];
                });

                subTextEntries.push(i18nc("Comma-separated list of desktops", "On %1",
                    virtualDesktopNameList.join(", ")));
            } else if (isOnAllVirtualDesktops) {
                subTextEntries.push(i18nc("Comma-separated list of desktops", "Pinned to all desktops"));
            }
        }

        if (activities.length === 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(i18nc("Which virtual desktop a window is currently on",
                "Available on all activities"));
        } else if (activities.length > 0) {
            const activityNames = activities
                .filter(activity => activity !== activityInfo.currentActivity)
                .map(activity => activityInfo.activityName(activity))
                .filter(activityName => activityName !== "");

            if (Plasmoid.configuration.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(i18nc("Activities a window is currently on (apart from the current one)",
                        "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(i18nc("Which activities a window is currently on",
                    "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join(", ");
    }
}
