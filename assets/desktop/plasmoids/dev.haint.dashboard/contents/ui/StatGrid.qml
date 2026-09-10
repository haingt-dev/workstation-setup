// =============================================================================
// StatGrid.qml — 2x2 CPU/RAM/GPU/Disk cards, owns all the data plumbing
// =============================================================================
// ksysguard (org.kde.ksysguard.sensors) covers usage numbers fine, but this
// box's org.kde.ksystemstats1 has no allSensors D-Bus method to enumerate
// what temperature/disk sensor IDs even exist — so every temperature and the
// disk usage sensor is a guess that may just never turn Ready. Each one is
// paired with a shell probe (contents/tools/probe.sh) as fallback: prefer the
// ksysguard value when it is actually a finite number, otherwise take the
// probe's. The probe itself is only polled when at least one field it would
// supply isn't already covered — see `probeNeeded` below.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

import "."

GridLayout {
    id: root
    property var guard   // set by main.qml; must NOT be named gameGuard (would shadow the outer id)

    columns: 2
    rowSpacing: 10
    columnSpacing: 10

    // ── ksysguard sensors ────────────────────────────────────────────────────
    // sensorId guesses beyond cpu/all/usage and the memory ones are unverifiable
    // on this box (no allSensors introspection) — validity is judged purely by
    // "did a finite number come back", never by trusting the id resolved.
    Sensors.Sensor { id: cpuUsageS;   sensorId: "cpu/all/usage";               enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: cpuTempS;    sensorId: "cpu/all/averageTemperature";  enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: ramUsedS;    sensorId: "memory/physical/used";        enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: ramTotalS;   sensorId: "memory/physical/total";       enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: ramPctS;     sensorId: "memory/physical/usedPercent"; enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: gpuUsageS;   sensorId: "gpu/gpu0/usage";              enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: diskPctS;    sensorId: "disk/all/usedPercent";        enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: gpuTempS;    sensorId: "gpu/gpu0/temperature";        enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: coresS;      sensorId: "cpu/all/coreCount";           enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: diskUsedS;   sensorId: "disk/all/used";               enabled: !!root.guard && !root.guard.paused }
    Sensors.Sensor { id: diskTotS;    sensorId: "disk/all/total";              enabled: !!root.guard && !root.guard.paused }

    function finite(v) {
        const n = Number(v);
        return v !== undefined && v !== null && !isNaN(n) && isFinite(n);
    }

    readonly property bool cpuTempValid: finite(cpuTempS.value)
    readonly property bool gpuUsageValid: finite(gpuUsageS.value)
    readonly property bool diskPctValid: finite(diskPctS.value)
    readonly property bool gpuTempValid: finite(gpuTempS.value)
    readonly property bool coresValid: finite(coresS.value)
    readonly property bool diskSizeValid: finite(diskUsedS.value) && finite(diskTotS.value) && diskTotS.value > 0

    // The probe is a FALLBACK, not the data path. Every sensorId above resolves
    // on this machine, so this evaluates false here and probe.sh is never
    // spawned; it exists for a box where ksystemstats is missing a plugin
    // (no NVIDIA GPU sensor, a kernel without the temp driver, ...).
    readonly property bool probeNeeded: !cpuTempValid || !gpuUsageValid || !diskPctValid
                                        || !gpuTempValid || !coresValid || !diskSizeValid

    // "sh <path>" rather than executing the path directly — Write-tool-created
    // files ship 644, and depending on +x surviving install/packaging is a
    // landmine we don't need to step on.
    // decodeURIComponent + quotes: Qt percent-encodes the URL, and the
    // executable engine splits the string with KShell::splitArgs, so a space
    // anywhere in $HOME would otherwise arrive as a literal %20.
    readonly property string probeCmd: "sh '" +
        decodeURIComponent(Qt.resolvedUrl("../tools/probe.sh").toString().replace("file://", "")) + "'"

    // ── probe.sh fallback, polled every 10s while a game isn't hogging screen ──
    P5Support.DataSource {
        id: probeSrc
        engine: "executable"
        connectedSources: []
        property var parsed: ({})

        onNewData: (source, data) => {
            disconnectSource(source);
            watchdog.stop();
            try {
                parsed = JSON.parse(data["stdout"] || "{}");
            } catch (e) {
                parsed = {};
            }
        }
    }

    // A hung probe (disk stall, sensors wedged) must not pile up connections
    // forever — 15s is comfortably above the sub-200ms this script normally
    // takes, so anything still running past it is dead and gets cut loose.
    // No explicit "running: !paused" gate here (repeat:false + imperative
    // restart()/stop() don't mix with a reactive running binding — restart()
    // would just clobber it) — it is only ever armed from probeTimer's
    // onTriggered, which IS gated, so this can never start while paused.
    Timer {
        id: watchdog
        interval: 15000
        repeat: false
        onTriggered: {
            if (probeSrc.connectedSources.length > 0)
                probeSrc.disconnectSource(probeSrc.connectedSources[0]);
        }
    }

    Timer {
        id: probeTimer
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: !!root.guard && !root.guard.paused && root.probeNeeded
        onTriggered: {
            if (probeSrc.connectedSources.length > 0)
                return; // previous run still in flight
            probeSrc.connectSource(root.probeCmd);
            watchdog.restart();
        }
    }

    Connections {
        target: root.guard
        function onResumed() {
            if (root.probeNeeded && probeSrc.connectedSources.length === 0)
                probeTimer.restart();
        }
    }

    function gib(bytes) { return (Number(bytes) / 1073741824).toFixed(1); }

    // ── CPU ──────────────────────────────────────────────────────────────────
    StatCard {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        iconName: "cpu"
        value: Math.round(cpuUsageS.value || 0) + "%"
        secondary: {
            const t = root.cpuTempValid ? Math.round(cpuTempS.value) : probeSrc.parsed.cpuTemp;
            const cores = root.coresValid ? Math.round(coresS.value) : probeSrc.parsed.cores;
            const parts = [];
            if (t !== undefined && t !== null) parts.push(Math.round(t) + "°C");
            if (cores) parts.push(cores + " cores");
            return parts.join(" · ") || "—";
        }
    }

    // ── RAM ──────────────────────────────────────────────────────────────────
    StatCard {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        iconName: "dialog-memory-symbolic"
        value: {
            if (root.finite(ramPctS.value)) return Math.round(ramPctS.value) + "%";
            if (root.finite(ramTotalS.value) && ramTotalS.value > 0)
                return Math.round((ramUsedS.value / ramTotalS.value) * 100) + "%";
            return "--%";
        }
        secondary: root.finite(ramTotalS.value) && ramTotalS.value > 0
            ? root.gib(ramUsedS.value) + " / " + root.gib(ramTotalS.value) + " GiB"
            : "—"
    }

    // ── GPU ──────────────────────────────────────────────────────────────────
    StatCard {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        iconName: "show-gpu-effects-symbolic"
        value: {
            if (root.gpuUsageValid) return Math.round(gpuUsageS.value) + "%";
            if (probeSrc.parsed.gpuUsage !== undefined && probeSrc.parsed.gpuUsage !== null)
                return Math.round(probeSrc.parsed.gpuUsage) + "%";
            return "--%";
        }
        secondary: {
            if (root.gpuTempValid) return Math.round(gpuTempS.value) + "°C";
            if (probeSrc.parsed.gpuTemp !== undefined && probeSrc.parsed.gpuTemp !== null)
                return Math.round(probeSrc.parsed.gpuTemp) + "°C";
            return "—";
        }
    }

    // ── DISK ─────────────────────────────────────────────────────────────────
    StatCard {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        iconName: "drive-harddisk-symbolic"
        value: {
            if (root.diskPctValid) return Math.round(diskPctS.value) + "%";
            if (probeSrc.parsed.diskUsedPct !== undefined && probeSrc.parsed.diskUsedPct !== null)
                return Math.round(probeSrc.parsed.diskUsedPct) + "%";
            return "--%";
        }
        // Both lines must describe the SAME disks. The percentage comes from
        // disk/all, so the sizes do too — pairing it with probe.sh's `df /home`
        // put "28%" over "297G / 929G" (=33%), two numbers contradicting each
        // other on one card.
        secondary: {
            if (root.diskSizeValid)
                return root.gib(diskUsedS.value) + " / " + root.gib(diskTotS.value) + " GiB";
            if (probeSrc.parsed.diskUsed && probeSrc.parsed.diskTotal)
                return probeSrc.parsed.diskUsed + " / " + probeSrc.parsed.diskTotal;
            return "—";
        }
    }
}
