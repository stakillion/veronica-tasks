/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 stakillion

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: audioStreamIconBox
    anchors.fill: parent

    activeFocusOnTab: true

    // Circular translucent dark badge for maximum contrast over any application icon
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(0.08, 0.08, 0.08, 0.88)
        border.color: hoverHandler.hovered
            ? Qt.rgba(frame.accentColor.r, frame.accentColor.g, frame.accentColor.b, 0.95)
            : Qt.rgba(1.0, 1.0, 1.0, 0.35)
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Kirigami.Icon {
        id: audioStreamIcon
        anchors.fill: parent
        anchors.margins: 2

        source: task.muted
            ? ("audio-volume-muted-symbolic" + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : ""))
            : ("audio-volume-high-symbolic" + (Application.layoutDirection === Qt.RightToLeft ? "-rtl" : ""))
        selected: tapHandler.pressed
    }

    Keys.onReturnPressed: event => task.toggleMuted()
    Keys.onEnterPressed: event => Keys.returnPressed(event)
    Keys.onSpacePressed: event => Keys.returnPressed(event)

    Accessible.checkable: true
    Accessible.checked: task.muted
    Accessible.name: task.muted ? i18nc("@action:button", "Unmute") : i18nc("@action:button", "Mute")
    Accessible.description: task.muted ? i18nc("@info:tooltip %1 is the window title", "Unmute %1", model.display) : i18nc("@info:tooltip %1 is the window title", "Mute %1", model.display)
    Accessible.role: Accessible.Button

    HoverHandler {
        id: hoverHandler
        enabled: Plasmoid.configuration.interactiveMute
    }

    TapHandler {
        id: tapHandler
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: Plasmoid.configuration.interactiveMute
        onTapped: (eventPoint, button) => task.toggleMuted()
    }
}
