/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

T.ProgressBar {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    hoverEnabled: false
    padding: 0

    from: 0
    to: 100
    value: task.smartLauncherItem ? task.smartLauncherItem.progress : 0

    contentItem: Item {
        clip: true

        Rectangle {
            id: progressFrame

            LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * control.position
            height: parent.height
            radius: 5

            color: Qt.rgba(0.18, 0.75, 0.30, 0.40)
        }
    }

    background: null
}
