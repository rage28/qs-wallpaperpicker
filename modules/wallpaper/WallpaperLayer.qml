pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.modules.desktoptheme
import qs.services as Services

// The desktop background, one window per screen on the Background layer: the
// wallpaper (services/WallpaperEngine) and, over it in the same surface, the
// active desktop theme's layer. Desktop widgets and windows sit above.
//
// Two slots take turns: the new wallpaper loads into the hidden one, the
// theme's transition (shaders/wallpaper_transition.frag) runs from the shown
// one to it, then they swap. A slot draws a still image or animated GIF/WebP.
// Idle, it is just that one item. A
// theme layer that reworks the wallpaper itself (Broadsheet's halftone) gets
// a texture of all this, transitions included, which exists only while it's
// wanted.
Scope {
    Variants {
        // None while another program draws the wallpaper (a wallpaper
        // command is set).
        model: Services.WallpaperEngine.external ? [] : Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            // Transition per desktop theme (see the shader).
            readonly property var modes: ({ "": 0, hud: 1, terminal: 2, cosmos: 3, zen: 4, xianxia: 5, cyberpunk: 6, wabisabi: 7, artdeco: 8, gothic: 9, newspaper: 10, wasteland: 11, observatory: 12, abyss: 13, devaloka: 14, siege: 15 })
            readonly property int mode: modes[Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""] ?? 0

            property Wall front: imgA
            readonly property Wall back: front === imgA ? imgB : imgA
            property real progress: 0
            property bool waiting: false
            function show(path) {
                if (!path)
                    return;
                if (!front.path) {
                    front.path = path;
                    return;
                }
                if (front.path === path)
                    return;
                if (anim.running) {
                    anim.stop();
                    finish();
                }
                back.path = path;
                waiting = true;
                if (back.ready)
                    start();
            }

            function start() {
                waiting = false;
                progress = 0;
                // Under the picker's chosen card: straight in.
                if (Services.WallpaperEngine.pickerCovers === modelData.name) {
                    finish();
                    return;
                }
                anim.duration = ({ 1: 1300, 4: 1500, 6: 950, 7: 1400, 8: 1400, 9: 1500, 10: 1600, 11: 1500, 12: 1500, 13: 1600, 14: 1500, 15: 1600 })[mode] ?? 1100;
                anim.start();
            }

            function finish() {
                const old = front;
                front = back;
                progress = 0;
                // Under the picker's chosen card, defer unloading the old
                // image until the picker is gone.
                if (Services.WallpaperEngine.pickerCovers === modelData.name)
                    old.retired = true;
                else
                    old.path = "";
                Services.WallpaperEngine.drawn = front.path;
            }

            function unloadRetired() {
                for (const w of [imgA, imgB]) {
                    if (w.retired && w !== front)
                        w.path = "";
                }
            }

            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: Colors.background
            mask: Region {}

            Component.onCompleted: show(Services.WallpaperEngine.current)

            Connections {
                target: Services.WallpaperEngine

                function onCurrentChanged() {
                    win.show(Services.WallpaperEngine.current);
                }

                function onPickerCoversChanged() {
                    if (Services.WallpaperEngine.pickerCovers !== win.modelData.name)
                        retireTimer.restart();
                }
            }

            // Not as the picker goes (its own preview unloads then).
            Timer {
                id: retireTimer
                interval: 1500
                onTriggered: win.unloadRetired()
            }

            // One slot: whatever `path` is, cropped to fill the screen.
            component Wall: Item {
                id: wall

                property string path: ""
                // Replaced under the picker, paused till it's unloaded.
                property bool retired: false
                readonly property string kind: Services.WallpaperEngine.kind(path)
                // Something to show.
                readonly property bool ready: !!loader.item && loader.item.ready
                readonly property bool failed: !!loader.item && loader.item.failed

                anchors.fill: parent

                onPathChanged: retired = false
                onReadyChanged: {
                    if (ready && win.waiting && wall === win.back)
                        win.start();
                    // The first wallpaper: no transition.
                    if (ready && wall === win.front)
                        Services.WallpaperEngine.drawn = wall.path;
                }
                onFailedChanged: {
                    if (failed && wall === win.back)
                        win.waiting = false;
                }

                Loader {
                    id: loader
                    anchors.fill: parent
                    sourceComponent: !wall.path ? null : wall.kind === "animated" ? animated : still
                }

                Component {
                    id: still

                    Image {
                        readonly property bool ready: status === Image.Ready
                        readonly property bool failed: status === Image.Error

                        source: "file://" + wall.path
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(Math.max(1, win.width), Math.max(1, win.height))
                        asynchronous: true
                        cache: false
                        smooth: true
                    }
                }

                // Frames are decoded as they're shown (cache: false), not
                // all held in memory.
                Component {
                    id: animated

                    AnimatedImage {
                        readonly property bool ready: status === Image.Ready
                        readonly property bool failed: status === Image.Error

                        source: "file://" + wall.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        playing: true
                        paused: wall.retired
                    }
                }
            }

            // The wallpaper as drawn: both slots and the transition. The
            // transition reads the slots through textures that live only
            // while it runs.
            Item {
                id: stack
                anchors.fill: parent

                Wall {
                    id: imgA
                    z: win.front === imgA ? 1 : 0
                }

                Wall {
                    id: imgB
                    z: win.front === imgB ? 1 : 0
                }

                ShaderEffectSource {
                    id: fromSource
                    anchors.fill: parent
                    visible: false
                    sourceItem: anim.running ? win.front : null
                    textureSize: Qt.size(width * win.modelData.devicePixelRatio, height * win.modelData.devicePixelRatio)
                }

                ShaderEffectSource {
                    id: toSource
                    anchors.fill: parent
                    visible: false
                    sourceItem: anim.running ? win.back : null
                    textureSize: fromSource.textureSize
                }

                ShaderEffect {
                    anchors.fill: parent
                    z: 2
                    visible: anim.running

                    property var fromTex: fromSource
                    property var toTex: toSource
                    property real progress: win.progress
                    property real mode: win.mode
                    property real aspect: width / Math.max(1, height)
                    property color edgeColor: Services.DesktopTheme.accent
                    property vector4d fromRect: Qt.vector4d(0, 0, 1, 1)
                    property vector4d toRect: Qt.vector4d(0, 0, 1, 1)

                    fragmentShader: Qt.resolvedUrl("../../shaders/wallpaper_transition.frag.qsb")
                }
            }

            // Only when the theme layer reworks the wallpaper.
            ShaderEffectSource {
                id: stackTexture
                width: win.width
                height: win.height
                visible: false
                sourceItem: (themeLoader.item as ThemeLayer)?.usesWallpaper ? stack : null
            }

            NumberAnimation {
                id: anim
                target: win
                property: "progress"
                from: 0
                to: 1
                easing.type: Easing.InOutCubic
                onFinished: win.finish()
            }

            Loader {
                id: themeLoader
                anchors.fill: parent
                z: 3
                active: Services.DesktopTheme.enabled
                sourceComponent: ThemeLayer {
                    wallpaper: stackTexture
                }
            }
        }
    }
}
