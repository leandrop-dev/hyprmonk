// A card opening or closing, on the shared curve and time (services/Motion.qml).
import QtQuick
import qs.services

NumberAnimation {
    duration: Motion.card
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve
}
