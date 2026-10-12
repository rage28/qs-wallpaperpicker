import QtQuick
import QtTest
import "../lib/WallpaperLogic.js" as WallpaperLogic

TestCase {
    name: "WallpaperLogic"

    function names(wallpapers) {
        return wallpapers.map(w => w.fileName).join(",");
    }

    function test_baseName() {
        compare(WallpaperLogic.baseName("aurora.wallpaper.webp"), "aurora.wallpaper");
        compare(WallpaperLogic.baseName("README"), "README");
        compare(WallpaperLogic.baseName(".hidden"), ".hidden");
    }

    function test_humanReadableNumbers() {
        compare(WallpaperLogic.bytes(0), "1 KB");
        compare(WallpaperLogic.bytes(1536), "2 KB");
        compare(WallpaperLogic.bytes(1572864), "1.5 MB");
        compare(WallpaperLogic.compact(999), "999");
        compare(WallpaperLogic.compact(1250), "1.3k");
        compare(WallpaperLogic.compact(12500), "13k");
    }

    function test_filterFavorites() {
        const input = [{ fileName: "a.jpg" }, { fileName: "b.jpg" }, { fileName: "c.jpg" }];
        compare(names(WallpaperLogic.filterFavorites(input, ["c.jpg", "a.jpg"])), "a.jpg,c.jpg");
        compare(names(WallpaperLogic.filterFavorites(input, [])), "");
    }

    function test_sortNameKeepsFolderOrder() {
        const input = [{ fileName: "b.jpg" }, { fileName: "a.jpg" }];
        compare(names(WallpaperLogic.sortWallpapers(input, "name", () => 0)), "b.jpg,a.jpg");
        compare(names(input), "b.jpg,a.jpg");
    }

    function test_sortNewestIsStable() {
        const input = [
            { fileName: "old.jpg", modified: 1 },
            { fileName: "new-a.jpg", modified: 3 },
            { fileName: "new-b.jpg", modified: 3 }
        ];
        compare(names(WallpaperLogic.sortWallpapers(input, "newest", () => 0)), "new-a.jpg,new-b.jpg,old.jpg");
    }

    function test_sortColourIsStable() {
        const input = [{ fileName: "blue.jpg" }, { fileName: "red-a.jpg" }, { fileName: "red-b.jpg" }];
        const hues = { "blue.jpg": 0.6, "red-a.jpg": 0.1, "red-b.jpg": 0.1 };
        compare(names(WallpaperLogic.sortWallpapers(input, "colour", name => hues[name])), "red-a.jpg,red-b.jpg,blue.jpg");
    }

    function test_imageKind() {
        compare(WallpaperLogic.kind("still.JPG"), "image");
        compare(WallpaperLogic.kind("moving.GIF"), "animated");
        compare(WallpaperLogic.kind("moving.webp"), "animated");
        compare(WallpaperLogic.kind("removed.mp4"), "image");
        compare(WallpaperLogic.kind("removed.webm"), "image");
    }

    function test_paths() {
        compare(WallpaperLogic.expandHome("~/Pictures/a.jpg", "/home/test"), "/home/test/Pictures/a.jpg");
        compare(WallpaperLogic.tildeHome("/home/test/Pictures/a.jpg", "/home/test"), "~/Pictures/a.jpg");
        compare(WallpaperLogic.resolve("a.jpg", "/wallpapers", "/home/test"), "/wallpapers/a.jpg");
        compare(WallpaperLogic.resolve("file:///tmp/a.jpg", "/wallpapers", "/home/test"), "/tmp/a.jpg");
    }

    function test_fileInCommand() {
        compare(WallpaperLogic.fileInCommand("swww img {}"), "swww img \"$1\"");
        compare(WallpaperLogic.fileInCommand("tool --file=\"{}\""), "tool --file=\"$1\"");
        compare(WallpaperLogic.fileInCommand("swaybg -m fill -i"), "swaybg -m fill -i \"$1\"");
    }

    function test_migrateLegacyWallpaperSettings() {
        const migrated = WallpaperLogic.migrateWallpaperSettings("", 0);
        compare(migrated.command, "noctalia msg wallpaper-set {}");
        compare(migrated.version, 1);

        const custom = WallpaperLogic.migrateWallpaperSettings("swww img {}", 0);
        compare(custom.command, "swww img {}");
        compare(custom.version, 1);

        const current = WallpaperLogic.migrateWallpaperSettings("", 1);
        compare(current.command, "");
        compare(current.version, 1);
    }
}
