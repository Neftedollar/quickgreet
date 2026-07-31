import QtQuick
import QuickMotion
import QtQuick.Layouts

// Time and date. Owns its own tick, so nothing outside has to remember to
// drive it.
ColumnLayout {
    id: root

    spacing: 2
    opacity: 0

    Component.onCompleted: intro.start()

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDateTime(clock.now, Config.timeFormat)
        color: Colours.m3onSurface
        font.family: Style.font.sans
        font.pixelSize: Style.size.clock
        font.weight: Font.Light
    }

    // The locale follows the language the greeter displays, not the
    // system's: they need not be the same.
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
            const d = clock.now.toLocaleDateString(Qt.locale(Strings.qtLocale), Config.dateFormat);
            return d.charAt(0).toUpperCase() + d.slice(1);
        }
        color: Colours.m3onSurfaceVariant
        font.family: Style.font.sans
        font.pixelSize: Style.size.date
    }

    Timer {
        id: clock

        property date now: new Date()

        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: now = new Date()
    }

    Anim {
        id: intro

        target: root
        property: "opacity"
        from: 0
        to: 1
        role: Motion.Fade
    }
}
