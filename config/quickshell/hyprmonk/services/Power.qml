// The power profile (power-profiles-daemon): its name, and the next one along.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var profiles: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]
    readonly property string profileName: nameOf(PowerProfiles.profile)

    function nameOf(profile: int): string {
        switch (profile) {
        case PowerProfile.PowerSaver: return "saver";
        case PowerProfile.Performance: return "performance";
        default: return "balanced";
        }
    }

    function nextProfile(): void {
        PowerProfiles.profile = profiles[(profiles.indexOf(PowerProfiles.profile) + 1) % profiles.length];
    }
}
