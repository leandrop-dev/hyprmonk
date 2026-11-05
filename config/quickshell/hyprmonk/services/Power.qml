// The power profile (power-profiles-daemon): its name, and setting one by
// name (quick actions' picker).
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
        case PowerProfile.PowerSaver: return I18n.mark("saver");
        case PowerProfile.Performance: return I18n.mark("performance");
        default: return I18n.mark("balanced");
        }
    }

    readonly property var names: profiles.map(nameOf)

    function setProfile(name: string): void {
        const profile = profiles.find(p => nameOf(p) === name);
        if (profile !== undefined) PowerProfiles.profile = profile;
    }
}
