/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.private.volume as PlasmaPa

QtObject {
    id: pulseAudio

    signal streamsChanged()

    property QtObject backend: null

    readonly property /*PlasmaPa.GlobalConfig*/ QtObject globalConfig: PlasmaPa.GlobalConfig { }

    // It's a JS object so we can do key lookup and don't need to take care of filtering duplicates.
    property var pidMatches: new Set()

    // TODO Evict cache at some point, preferably if all instances of an application closed.
    function registerPidMatch(appName: string) {
        if (!hasPidMatch(appName)) {
            pidMatches.add(appName);

            // In case this match is new, notify that streams might have changed.
            // This way we also catch the case when the non-playing instance
            // shows up first.
            // Only notify if we changed to avoid infinite recursion.
            streamsChanged();
        }
    }

    function hasPidMatch(appName: string): bool {
        return pidMatches.has(appName);
    }

    function findStreams(key: string, value: var): /*[QtObject]*/ var {
        return findStreamsFn(stream => stream[key] === value);
    }

    function findStreamsFn(fn: var): var {
        const streams = [];
        for (let i = 0, count = instantiator.count; i < count; ++i) {
            const stream = instantiator.objectAt(i);
            if (fn(stream)) {
                streams.push(stream);
            }
        }
        return streams;
    }

    function streamsForAppId(appId: string): /*[QtObject]*/ var {
        return findStreams("portalAppId", appId);
    }

    function streamsForAppName(appName: string): /*[QtObject]*/ var {
        return findStreams("appName", appName);
    }

    function streamsForTask(appId: string, appName: string, pid: int): var {
        const normAppId = (appId || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const normAppName = (appName || "").toLowerCase().replace(/[^a-z0-9]/g, "");

        return findStreamsFn(stream => {
            // 1. Direct PID match
            if (pid > 0 && (stream.pid === pid || stream.parentPid === pid)) {
                return true;
            }

            // 2. Flatpak / Wayland portal App ID match
            if (stream.portalAppId && normAppId.length > 0) {
                const normPortal = stream.portalAppId.toLowerCase().replace(/[^a-z0-9]/g, "");
                if (normPortal === normAppId || normAppId.includes(normPortal) || normPortal.includes(normAppId)) {
                    return true;
                }
            }

            // 3. Process binary match
            if (stream.binary && stream.binary.length > 1) {
                const normBinary = stream.binary.toLowerCase().replace(/[^a-z0-9]/g, "");
                if (normBinary.length > 1) {
                    if (normAppId.includes(normBinary) || normAppName.includes(normBinary)) {
                        return true;
                    }
                }
            }

            // 4. Application name match
            if (stream.appName && stream.appName.length > 1) {
                const normStreamApp = stream.appName.toLowerCase().replace(/[^a-z0-9]/g, "");
                if (normStreamApp.length > 1) {
                    if (normAppName.includes(normStreamApp) || normStreamApp.includes(normAppName) ||
                        normAppId.includes(normStreamApp) || normStreamApp.includes(normAppId)) {
                        return true;
                    }
                }
            }

            return false;
        });
    }

    function streamsForPid(pid: int): /*[QtObject]*/ var {
        // skip stream that has portalAppId
        // app using portal may have a sandbox pid
        const streams = findStreamsFn(stream => stream.pid === pid && !stream.portalAppId);

        if (streams.length === 0) {
            for (let i = 0, length = instantiator.count; i < length; ++i) {
                const stream = instantiator.objectAt(i) as StreamDelegate;

                if (stream.parentPid === -1) {
                    stream.parentPid = (backend && backend.parentPid) ? backend.parentPid(stream.pid) : 0;
                }

                if (stream.parentPid === pid) {
                    streams.push(stream);
                }
            }
        }

        return streams;
    }

    // QtObject has no default property, hence adding the Instantiator to one explicitly.
    readonly property Instantiator instantiator: Instantiator {
        model: PlasmaPa.PulseObjectFilterModel {
            filters: [ { role: "VirtualStream", value: false } ]
            sourceModel: PlasmaPa.SinkInputModel {}
        }

        component StreamDelegate: QtObject {
            id: delegate
            required property var model
            readonly property int pid: model.Client?.properties["application.process.id"] ?? 0
            // Determined on demand.
            property int parentPid: -1
            readonly property string appName: model.Client?.properties["application.name"] ?? ""
            readonly property string binary: model.Client?.properties["application.process.binary"] ?? ""
            readonly property string portalAppId: model.Client?.properties["pipewire.access.portal.app_id"] ?? ""
            readonly property bool muted: model.Muted
            // whether there is nothing actually going on on that stream
            readonly property bool corked: model.Corked
            readonly property int volume: model.Volume

            function mute(): void {
                model.Muted = true;
            }
            function unmute(): void {
                model.Muted = false;
            }
        }

        delegate: StreamDelegate { }

        onObjectAdded: (index, object) => pulseAudio.streamsChanged()
        onObjectRemoved: (index, object) => pulseAudio.streamsChanged()
    }

    readonly property int minimalVolume: PlasmaPa.PulseAudio.MinimalVolume
    readonly property int normalVolume: PlasmaPa.PulseAudio.NormalVolume
}
