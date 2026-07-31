pragma Singleton

import QtQuick
import Quickshell

// Design tokens.
//
// Before this existed the same values were written out wherever they were
// needed, and had drifted: six icon sizes where three were meant, three
// durations for visually identical hover fades. Naming them by role rather
// than by number is what keeps that from happening again.
//
// Font families come from Config: both are hard requirements that not
// every distribution packages conveniently, so they must be replaceable
// without editing QML.
//
// Note there is no radius token for pill shapes. Those are written
// `radius: height / 2` at the point of use, because a fixed number silently
// stops being half the height the moment a size token changes.
Singleton {
    id: root

    readonly property QtObject font: QtObject {
        readonly property string sans: Config.fontFamily
        readonly property string icons: Config.iconFontFamily
    }

    readonly property QtObject size: QtObject {
        readonly property int clock: 92
        readonly property int initial: 34
        readonly property int title: 19
        readonly property int body: 16
        readonly property int label: 13
        readonly property int caption: 11
        readonly property int date: 17

        readonly property int icon: 18
        readonly property int iconSmall: 16
        readonly property int iconLarge: 22
    }

    readonly property QtObject radius: QtObject {
        readonly property int card: 28
        readonly property int popup: 16
        readonly property int panel: 14
        readonly property int item: 12
        readonly property int itemSmall: 10
        readonly property int tip: 8
    }

    readonly property QtObject dur: QtObject {
        readonly property int quick: 150   // hover and colour fades
        readonly property int pop: 220     // one password dot arriving
        readonly property int intro: 420
        readonly property int shake: 55
        readonly property int blink: 480
        readonly property int spin: 900
    }

    readonly property QtObject pad: QtObject {
        readonly property int screen: 24
        readonly property int card: 24
        readonly property int field: 18
        readonly property int item: 12
        readonly property int chip: 20
    }

    readonly property QtObject dim: QtObject {
        readonly property int card: 380
        readonly property int avatar: 76
        readonly property int field: 48
        readonly property int chip: 34
        readonly property int button: 36
        readonly property int row: 38
        readonly property int rowSmall: 34
        readonly property int dot: 9
    }
}
