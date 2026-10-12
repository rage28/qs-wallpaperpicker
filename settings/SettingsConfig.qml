pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The picker's settings, kept in the user's config directory. The
// folder, command, API key and the chosen card's animation are set from the
// picker's gear; the Wallhaven filters from its chips; the animated-image
// preview from its play button.
Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/qs-wallpaperpicker"

    property alias wallpaperDir: settingsAdapter.wallpaperDir
    property alias wallpaperCommand: settingsAdapter.wallpaperCommand
    property alias wallpaperLivePreview: settingsAdapter.wallpaperLivePreview
    property alias wallpaperAnimateChoice: settingsAdapter.wallpaperAnimateChoice
    property alias wallhavenApiKey: settingsAdapter.wallhavenApiKey
    property alias wallhavenCategories: settingsAdapter.wallhavenCategories
    property alias wallhavenPurity: settingsAdapter.wallhavenPurity
    property alias wallhavenSorting: settingsAdapter.wallhavenSorting
    property alias wallhavenOrder: settingsAdapter.wallhavenOrder
    property alias wallhavenTopRange: settingsAdapter.wallhavenTopRange
    property alias wallhavenAtleast: settingsAdapter.wallhavenAtleast
    property alias wallhavenRatios: settingsAdapter.wallhavenRatios

    Timer {
        id: writeTimer
        interval: 100
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        onTriggered: settingsFile.reload()
    }

    function migrateWallpaperSettings() {
        if (settingsAdapter.wallpaperSettingsVersion >= 1)
            return;
        // Existing installs used an empty command for the built-in renderer.
        // Move them to the new Noctalia owner once; users may still clear it
        // afterwards to opt back into the built-in image layer.
        if (settingsAdapter.wallpaperCommand.trim() === "")
            settingsAdapter.wallpaperCommand = "noctalia msg wallpaper-set {}";
        settingsAdapter.wallpaperSettingsVersion = 1;
    }

    FileView {
        id: settingsFile
        path: root.configDir + "/settings.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.migrateWallpaperSettings()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                root.migrateWallpaperSettings();
                writeTimer.restart();
            }
        }

        adapter: JsonAdapter {
            id: settingsAdapter
            property string wallpaperDir: "~/Pictures/wallpapers"
            // Noctalia owns the wallpaper by default. Other Wayland wallpaper
            // tools can still be configured here; "" uses the built-in layer.
            property string wallpaperCommand: "noctalia msg wallpaper-set {}"
            property int wallpaperSettingsVersion: 0
            // Animated GIF/WebP pictures play in the preview
            property bool wallpaperLivePreview: false
            // The card set grows into the wallpaper (false: set straight
            // away, the deck stays open)
            property bool wallpaperAnimateChoice: true
            property string wallhavenApiKey: ""
            property string wallhavenCategories: "111"
            property string wallhavenPurity: "100"
            property string wallhavenSorting: "toplist"
            property string wallhavenOrder: "desc"
            property string wallhavenTopRange: "1M"
            property string wallhavenAtleast: ""
            property string wallhavenRatios: ""
        }
    }
}
