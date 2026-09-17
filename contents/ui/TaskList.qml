/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

GridLayout {
    property bool animating: false

    rowSpacing: 0
    columnSpacing: 0

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    readonly property real minimumWidth: children
        .filter(item => item.visible && item.width > 0)
        .reduce((minimumWidth, item) => Math.min(minimumWidth, item.width), Infinity)

    readonly property int stripeCount: {
        if (Plasmoid.configuration.maxStripes === 1) {
            return 1;
        }
        if (Plasmoid.configuration.forceStripes) {
            return Plasmoid.configuration.maxStripes;
        }

        const firstItem = children.find(item => item.visible && item.implicitWidth > 0);
        const itemWidth = firstItem ? firstItem.implicitWidth : (vertical ? parent.width : 44);
        const itemHeight = firstItem ? firstItem.implicitHeight : (vertical ? 44 : parent.height);

        // The maximum number of stripes allowed by the applet's size
        const stripeSizeLimit = vertical
            ? Math.floor(parent.width / Math.max(1, itemWidth))
            : Math.floor(parent.height / Math.max(1, itemHeight));
        const maxStripes = Math.min(Plasmoid.configuration.maxStripes, Math.max(1, stripeSizeLimit));

        // The number of tasks that will fill a "stripe" before starting the next one
        const maxTasksPerStripe = vertical
            ? Math.ceil(parent.height / Math.max(1, itemHeight))
            : Math.ceil(parent.width / Math.max(1, itemWidth));

        return Math.min(Math.ceil(count / Math.max(1, maxTasksPerStripe)), maxStripes);
    }

    readonly property int orthogonalCount: {
        return Math.ceil(count / stripeCount);
    }

    rows: vertical ? orthogonalCount : stripeCount
    columns: vertical ? stripeCount : orthogonalCount
}
