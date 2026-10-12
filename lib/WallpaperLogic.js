.pragma library

var defaultWallpaperCommand = "noctalia msg wallpaper-set {}";

function baseName(name) {
    const dot = name.lastIndexOf(".");
    return dot > 0 ? name.substring(0, dot) : name;
}

function bytes(n) {
    return n >= 1048576 ? (n / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(n / 1024)) + " KB";
}

function compact(n) {
    return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k" : String(n);
}

function filterFavorites(wallpapers, favorites) {
    return wallpapers.filter(w => favorites.indexOf(w.fileName) >= 0);
}

function sortWallpapers(wallpapers, order, hueKey) {
    const list = wallpapers.map((w, i) => ({ w, i }));
    if (order === "newest") {
        list.sort((a, b) => (b.w.modified - a.w.modified) || (a.i - b.i));
    } else if (order === "colour") {
        const key = {};
        for (const x of list)
            key[x.w.fileName] = hueKey(x.w.fileName);
        list.sort((a, b) => (key[a.w.fileName] - key[b.w.fileName]) || (a.i - b.i));
    }
    return list.map(x => x.w);
}

function kind(path) {
    const p = String(path ?? "").toLowerCase();
    return /\.(gif|webp)$/.test(p) ? "animated" : "image";
}

function expandHome(path, home) {
    const p = String(path ?? "").trim();
    return p === "~" || p.startsWith("~/") ? home + p.substring(1) : p;
}

function tildeHome(path, home) {
    return path === home || path.startsWith(home + "/") ? "~" + path.substring(home.length) : path;
}

function resolve(path, dir, home) {
    let p = expandHome(String(path ?? "").trim().replace(/^file:\/\//, ""), home);
    if (p.length > 0 && !p.startsWith("/"))
        p = dir + "/" + p;
    return p;
}

// Turn a wallpaper command into a shell fragment that receives the file as
// $1. Placeholders keep the surrounding shell quote context; commands with
// no placeholder get the safely quoted argument appended.
function fileInCommand(cmd) {
    let out = "";
    let quote = "";
    let found = false;
    for (let i = 0; i < cmd.length; i++) {
        const c = cmd[i];
        if (c === "{" && cmd[i + 1] === "}") {
            found = true;
            i++;
            out += quote === "'" ? "'\"$1\"'" : quote === "\"" ? "$1" : "\"$1\"";
            continue;
        }
        if (c === "\\" && quote !== "'") {
            out += c + (cmd[i + 1] ?? "");
            i++;
            continue;
        }
        if (quote === "" && (c === "'" || c === "\""))
            quote = c;
        else if (c === quote)
            quote = "";
        out += c;
    }
    return found ? out : out + ' "$1"';
}

function migrateWallpaperSettings(command, version) {
    if (version >= 1)
        return { command, version };
    return {
        command: command.trim() === "" ? defaultWallpaperCommand : command,
        version: 1
    };
}
