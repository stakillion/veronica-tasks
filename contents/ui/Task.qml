/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools
import org.kde.plasma.plasmoid

import org.kde.taskmanager as TaskManager

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    HoverHandler {
        id: taskHoverHandler
        onPointChanged: {
            if (hovered && point?.position?.x !== undefined) {
                frame.glowCenterX = point.position.x - frame.x;
            }
        }
    }

    // To achieve a bottom-to-top layout on vertical panels, the task manager
    // is rotated by 180 degrees(see main.qml). This makes the tasks rotated,
    // so un-rotate them here to fix that.
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property real taskWidth: {
        if (inPopup) {
            return -1;
        }
        if (tasksRoot.vertical) {
            return tasksRoot.width / Math.max(1, taskList.columns);
        }
        const baseHeight = Math.max(16, tasksRoot.height / Math.max(1, taskList.rows));
        const spacingExtra = (Plasmoid.configuration.iconSpacing === 0) ? 4
                           : (Plasmoid.configuration.iconSpacing === 1) ? 18
                           : (Plasmoid.configuration.iconSpacing === 3) ? 38
                           : Math.round(Plasmoid.configuration.iconSpacing * 12);
        return Math.round(baseHeight + spacingExtra);
    }

    readonly property real taskHeight: {
        if (inPopup) {
            return LayoutMetrics.preferredHeightInPopup();
        }
        if (!tasksRoot.vertical) {
            return Math.max(16, tasksRoot.height / Math.max(1, taskList.rows));
        }
        const baseWidth = Math.max(16, tasksRoot.width / Math.max(1, taskList.columns));
        const spacingExtra = (Plasmoid.configuration.iconSpacing === 0) ? 4
                           : (Plasmoid.configuration.iconSpacing === 1) ? 18
                           : (Plasmoid.configuration.iconSpacing === 3) ? 38
                           : Math.round(Plasmoid.configuration.iconSpacing * 12);
        return Math.round(baseWidth + spacingExtra);
    }

    implicitWidth: inPopup ? -1 : taskWidth
    implicitHeight: taskHeight

    Layout.preferredWidth: inPopup ? -1 : taskWidth
    Layout.minimumWidth: inPopup ? -1 : taskWidth
    Layout.maximumWidth: inPopup ? -1 : taskWidth
    Layout.fillWidth: inPopup

    Layout.preferredHeight: taskHeight
    Layout.minimumHeight: taskHeight
    Layout.maximumHeight: inPopup ? taskHeight : taskHeight
    Layout.fillHeight: false

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId ? model.AppId.replace(/\.desktop/, '') : ""
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup
    property QtObject smartLauncherItem: null
    readonly property var pulseAudio: tasksRoot ? tasksRoot.pulseAudio : null

    readonly property Item audioStreamIcon: audioIndicatorLoader.item
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool tooltipControlsEnabled: Plasmoid.configuration.tooltipControls
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    active: !inPopup && !tasksRoot.groupDialog && task.contextMenu?.status !== PlasmaExtras.Menu.Open
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: !Plasmoid.configuration.showToolTips || !model.IsWindow ? pinnedAppToolTipDelegate : openWindowToolTipDelegate

    onXChanged: {
        if (!completed) {
            return;
        }
        if (oldX < 0) {
            oldX = x;
            return;
        }
        moveAnim.x = oldX - x + translateTransform.x;
        moveAnim.y = translateTransform.y;
        oldX = x;
        moveAnim.restart();
    }
    onYChanged: {
        if (!completed) {
            return;
        }
        if (oldY < 0) {
            oldY = y;
            return;
        }
        moveAnim.y = oldY - y + translateTransform.y;
        moveAnim.x = translateTransform.x;
        oldY = y;
        moveAnim.restart();
    }

    property real oldX: -1
    property real oldY: -1
    SequentialAnimation {
        id: moveAnim
        property real x
        property real y
        onRunningChanged: {
            if (running) {
                ++task.parent.animationsRunning;
            } else {
                --task.parent.animationsRunning;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                from: moveAnim.x
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                from: moveAnim.y
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18nc("@info:usagetip %1 task name", "Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    function initSmartLauncher(): void {
        if (smartLauncherEnabled && !smartLauncherItem && TaskTools.hasSmartLauncher !== false) {
            try {
                const component = Qt.createComponent("plasma.applet.org.kde.plasma.taskmanager", "SmartLauncherItem");
                if (component.status === Component.Ready) {
                    const smartLauncher = component.createObject(task);
                    if (smartLauncher) {
                        smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
                        smartLauncherItem = smartLauncher;
                        TaskTools.hasSmartLauncher = true;
                    }
                } else {
                    TaskTools.hasSmartLauncher = false;
                }
                component.destroy();
            } catch (e) {
                TaskTools.hasSmartLauncher = false;
            }
        }
    }

    onSmartLauncherEnabledChanged: initSmartLauncher()



    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        return inPopup
            ? tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args) as ContextMenu;
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio ? pulseAudio.item : null;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        var streams = pa.streamsForTask ? pa.streamsForTask(task.appId, model.AppName, model.AppPid) : [];
        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);
        mainItem.isReadyForPainting = Qt.binding(() => model.Geometry?.width > 0 && model.Geometry?.height > 0);

        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? (smartLauncherItem?.count ?? 0) : 0);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio ? pulseAudio.item : null
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
        }
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (task.model.IsLauncher) {
                task.showContextMenu({showAllPlaces: true})
            } else {
                task.showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            if (task.active) {
                task.hideToolTip();
            }
            TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === Backend.NewInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === Backend.Close) {
                    tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === Backend.ToggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === Backend.ToggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === Backend.BringToCurrentDesktop) {
                    TaskTools.foreachChildTask((childIndex) => {
                        tasksModel.requestVirtualDesktops(childIndex, [virtualDesktopInfo.currentDesktopByScreenGeometry(tasksModel.data(childIndex, TaskManager.AbstractTasksModel.ScreenGeometry))]);
                    }, modelIndex(), tasksModel);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            task.tasksRoot.cancelHighlightWindows();
        }
    }

    // Underlying stacked cards for multi-window tasks: non-overlapping clipped bands
    // so underlying cards never double-draw or alpha-blend on top of each other!
    // Band 1: Card 1 (4px peeking band from frame.right to frame.right + 4)
    Item {
        id: c1Container
        visible: frame.isMultiWindow
        z: 1

        anchors.left: frame.right
        anchors.leftMargin: -1
        width: 5
        anchors.top: frame.top
        anchors.bottom: frame.bottom
        clip: true

        Rectangle {
            id: peekingCard1
            width: frame.width
            height: frame.height - 2
            radius: 3.5

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            color: frame.color
            border.color: frame.border.color
            border.width: frame.border.width

            // Internal glow for peekingCard1 respecting its rounded corners and borders
            Shape {
                anchors.fill: parent
                opacity: glowContainer.opacity

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: (taskHoverHandler.hovered && taskHoverHandler.point?.position?.x !== undefined
                            ? taskHoverHandler.point.position.x - (frame.x + 4)
                            : frame.glowCenterX - 4)
                        centerY: peekingCard1.height - 1
                        centerRadius: Math.max(frame.width, frame.height) * 2.2
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.60) }
                        GradientStop {
                            position: 0.15
                            color: Qt.rgba((1.0 + frame.accentColor.r) / 2, (1.0 + frame.accentColor.g) / 2, (1.0 + frame.accentColor.b) / 2, 0.45)
                        }
                        GradientStop {
                            position: 0.35
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.28)
                        }
                        GradientStop {
                            position: 0.60
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.12)
                        }
                        GradientStop {
                            position: 0.85
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.03)
                        }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    startX: 0
                    startY: 0
                    PathRectangle {
                        x: 1
                        y: 1
                        width: peekingCard1.width - 2
                        height: peekingCard1.height - 2
                        radius: peekingCard1.radius - 1
                    }
                }
            }

            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }
    }

    // Band 2: Card 2 (4px peeking band from card1.right to card1.right + 4, 3+ windows only)
    Item {
        id: c2Container
        visible: frame.isMultiWindow && frame.windowCount > 2
        z: 0

        anchors.left: c1Container.right
        anchors.leftMargin: -1
        width: 5
        anchors.top: frame.top
        anchors.bottom: frame.bottom
        clip: true

        Rectangle {
            id: peekingCard2
            width: frame.width
            height: frame.height - 4
            radius: 3

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            color: frame.color
            border.color: frame.border.color
            border.width: frame.border.width

            // Internal glow for peekingCard2 respecting its rounded corners and borders
            Shape {
                anchors.fill: parent
                opacity: glowContainer.opacity

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: (taskHoverHandler.hovered && taskHoverHandler.point?.position?.x !== undefined
                            ? taskHoverHandler.point.position.x - (frame.x + 8)
                            : frame.glowCenterX - 8)
                        centerY: peekingCard2.height - 1
                        centerRadius: Math.max(frame.width, frame.height) * 2.2
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.60) }
                        GradientStop {
                            position: 0.15
                            color: Qt.rgba((1.0 + frame.accentColor.r) / 2, (1.0 + frame.accentColor.g) / 2, (1.0 + frame.accentColor.b) / 2, 0.45)
                        }
                        GradientStop {
                            position: 0.35
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.28)
                        }
                        GradientStop {
                            position: 0.60
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.12)
                        }
                        GradientStop {
                            position: 0.85
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.03)
                        }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    startX: 0
                    startY: 0
                    PathRectangle {
                        x: 1
                        y: 1
                        width: peekingCard2.width - 2
                        height: peekingCard2.height - 2
                        radius: peekingCard2.radius - 1
                    }
                }
            }

            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }
    }

    // Main task card: spans full height (no top/bottom margins)
    Rectangle {
        id: frame
        z: 2

        readonly property color accentColor: Kirigami.Theme.highlightColor
        readonly property color brightAccentColor: Qt.lighter(accentColor, 1.25)
        readonly property color textColor: Kirigami.Theme.textColor
        readonly property bool isHovered: (taskHoverHandler.hovered || task.highlighted) && Plasmoid.configuration.taskHoverEffect
        readonly property bool isTaskActive: !model.IsLauncher && model.IsActive && !model.IsMinimized
        property real glowCenterX: width / 2
        property string basePrefix: "normal"
        property string prefix: ""

        readonly property bool isMultiWindow: !model.IsLauncher && ((model.IsGroupParent && childCount > 1) || (model.WinIdList && model.WinIdList.length > 1) || childCount > 1)
        readonly property int windowCount: model.WinIdList ? model.WinIdList.length : (model.IsGroupParent ? childCount : 1)

        width: isMultiWindow ? (windowCount > 2 ? parent.width - 12 : parent.width - 8) : (parent.width - 4)
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: isMultiWindow ? (windowCount > 2 ? -4 : -2) : 0
        radius: 4
        clip: true

        color: {
            if (model.IsLauncher) {
                // Unopened application: completely transparent even when hovered
                return "transparent";
            } else if (model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) {
                return Qt.rgba(1.0, 0.45, 0.0, 0.40);
            } else if (isTaskActive) {
                // Active (focused) window: a brighter, vibrant shade of the accent color
                return Qt.rgba(brightAccentColor.r, brightAccentColor.g, brightAccentColor.b, isHovered ? 0.50 : 0.38);
            } else {
                // Running inactive window: rounded, slightly transparent background
                return Qt.rgba(textColor.r, textColor.g, textColor.b, model.IsMinimized ? 0.04 : 0.08);
            }
        }

        border.color: {
            if (model.IsLauncher) {
                // Unopened application: no border even when hovered
                return "transparent";
            } else if (model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)) {
                return Qt.rgba(1.0, 0.45, 0.0, 0.90);
            } else if (isTaskActive) {
                // Active window: bright accent-colored borders
                return isHovered
                    ? Qt.rgba(brightAccentColor.r, brightAccentColor.g, brightAccentColor.b, 1.0)
                    : Qt.rgba(brightAccentColor.r, brightAccentColor.g, brightAccentColor.b, 0.90);
            } else if (isHovered) {
                // Hovering over an open window: vibrant accent-colored border
                return model.IsMinimized
                    ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55)
                    : Qt.rgba(brightAccentColor.r, brightAccentColor.g, brightAccentColor.b, 0.88);
            } else if (model.IsMinimized) {
                // Minimized window: faint subdued border
                return Qt.rgba(textColor.r, textColor.g, textColor.b, 0.10);
            } else {
                // Open un-minimized window: clearly visible border to distinguish from minimized tasks
                return Qt.rgba(textColor.r, textColor.g, textColor.b, 0.32);
            }
        }
        border.width: model.IsLauncher ? 0 : 1

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }

        // Windows 7-style cursor-following Aero glow (open windows with borders only)
        Item {
            id: glowContainer
            anchors.fill: parent
            z: 0

            visible: !model.IsLauncher
            opacity: (!model.IsLauncher && frame.isHovered) ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }

            // Top specular highlight line (Windows 7 Aero glass bevel, inside borders)
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: frame.radius
                    rightMargin: frame.radius
                    topMargin: 1
                }
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
            }

            // Radial spotlight entirely inside the card respecting rounded corners and border
            Shape {
                id: glowShape
                anchors.fill: parent

                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: (taskHoverHandler.hovered && taskHoverHandler.point?.position?.x !== undefined
                            ? taskHoverHandler.point.position.x - frame.x
                            : frame.glowCenterX)
                        centerY: frame.height - 1
                        centerRadius: Math.max(frame.width, frame.height) * 2.2
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.60) }
                        GradientStop {
                            position: 0.15
                            color: Qt.rgba((1.0 + frame.accentColor.r) / 2, (1.0 + frame.accentColor.g) / 2, (1.0 + frame.accentColor.b) / 2, 0.45)
                        }
                        GradientStop {
                            position: 0.35
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.28)
                        }
                        GradientStop {
                            position: 0.60
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.12)
                        }
                        GradientStop {
                            position: 0.85
                            color: Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.03)
                        }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    startX: 0
                    startY: 0
                    PathRectangle {
                        x: 1
                        y: 1
                        width: frame.width - 2
                        height: frame.height - 2
                        radius: frame.radius - 1
                    }
                }
            }
        }

        // Avoid repositioning delegate item after dragFinished
        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

            function setRequestedInhibitDnd(value: bool): void {
                // This is modifying the value in the panel containment that
                // inhibits accepting drag and drop, so that we don't accidentally
                // drop the task on this panel.
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value;
                    }
                }
            }

            onActiveChanged: {
                if (active) {
                    icon.grabToImage(result => {
                        if (!dragHandler.active) {
                            // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
                            return;
                        }
                        setRequestedInhibitDnd(true);
                        tasksRoot.dragSource = task;
                        dragHelper.Drag.imageSource = result.url;
                        dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                            [model.MimeType]: model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
                        };
                        dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    dragHelper.Drag.active = false;
                    dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader
        z: 3

        anchors.fill: frame
        asynchronous: false
        active: !!task.smartLauncherItem && task.smartLauncherItem.progressVisible

        source: "TaskProgressOverlay.qml"
    }

    Loader {
        id: iconBox
        z: 4

        anchors.centerIn: task.inPopup ? undefined : frame
        anchors.left: task.inPopup ? parent.left : undefined
        anchors.leftMargin: task.inPopup ? 6 : 0
        anchors.verticalCenter: task.inPopup ? parent.verticalCenter : undefined

        readonly property real iconSize: task.inPopup
            ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium)
            : Math.max(16, Math.min(frame.width - 10, frame.height - 10, Kirigami.Units.iconSizes.large))

        width: iconSize
        height: iconSize

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small
                && task.smartLauncherItem && task.smartLauncherItem.countVisible
        source: "TaskBadgeOverlay.qml"

        Kirigami.Icon {
            id: icon

            anchors.fill: parent

            active: task.highlighted
            enabled: true

            source: task.model.decoration
        }

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: task.model.IsStartup
            sourceComponent: busyIndicator
        }
    }

    Loader {
        id: audioIndicatorLoader
        z: 6

        anchors.top: frame.top
        anchors.right: frame.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
        width: 16
        height: 16

        active: task.hasAudioStream && task.audioIndicatorsEnabled
        visible: active && (task.playingAudio || task.muted)

        source: "AudioStream.qml"
    }

    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ? (task.audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

        // The accessible item of this element is only used for debugging
        // purposes, and it will never gain focus (thus it won't interfere
        // with screenreaders).
        Accessible.ignored: !visible
        Accessible.name: parent.Accessible.name + "-labelhint"

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                label.text: task.model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: task.model.IsLauncher

            PropertyChanges {
                frame.basePrefix: ""
            }
        },
        State {
            name: "attention"
            when: task.model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                frame.basePrefix: "attention"
            }
        },
        State {
            name: "minimized"
            when: task.model.IsMinimized

            PropertyChanges {
                frame.basePrefix: "minimized"
            }
        },
        State {
            name: "active"
            when: task.model.IsActive

            PropertyChanges {
                frame.basePrefix: "focus"
            }
        }
    ]

    Component.onCompleted: {
        initSmartLauncher();

        if (!inPopup && model.IsWindow) {
            const component = Qt.createComponent("GroupExpanderOverlay.qml");
            component.createObject(task);
            component.destroy();
            updateAudioStreams({delay: false});
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        completed = true;
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
