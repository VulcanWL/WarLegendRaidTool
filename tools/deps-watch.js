// WarLegend RaidTool - weekly watch of what the addon depends on outside the repo (not shipped).
// Usage: node tools/deps-watch.js [--issues]
// Reads tools/watch.json: embedded libraries (their upstream version), the addons we ported (latest release),
// Blizzard's add-on policy (edits of its first post), the Luacheck release used by the CI. Prints one line per source;
// a source whose upstream value differs from its "reviewed" value is CHANGED. --issues (the weekly workflow,
// .github/workflows/wlrt-deps-watch.yml, needs the gh CLI and GH_TOKEN) opens ONE GitHub issue per new upstream value,
// label deps-watch, assigned to $OWNER; an issue with the same title, open or closed, means already reported.
// Exit code 1 when a source could not be read (and, without --issues, when something changed).
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const REPO = path.join(__dirname, "..");
const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, "watch.json"), "utf8"));
const issues = process.argv.includes("--issues");
const HEADERS = { "User-Agent": "WarLegendRaidTool-watch", Accept: "application/json" };
if (process.env.GITHUB_TOKEN) HEADERS.Authorization = "Bearer " + process.env.GITHUB_TOKEN;

async function get(url, asJson) {
    const res = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(20000) });
    if (!res.ok) throw new Error("HTTP " + res.status + " for " + url);
    return asJson ? res.json() : res.text();
}

function localValue(src) {
    if (!src.local) return null;
    try {
        const m = fs.readFileSync(path.join(REPO, src.local.file), "utf8").match(new RegExp(src.local.pattern));
        return m ? m[1] : "?";
    } catch (e) { return "?"; }
}

async function upstream(src) {
    if (src.kind === "text") {
        const m = (await get(src.url)).match(new RegExp(src.pattern));
        if (!m) throw new Error("pattern not found in " + src.url);
        return { value: m[1], link: src.url.replace("https://raw.githubusercontent.com/", "https://github.com/").replace(/\/(master|main)\//, "/blob/$1/") };
    }
    if (src.kind === "github-release") {
        const r = await get("https://api.github.com/repos/" + src.repo + "/releases/latest", true);
        return { value: r.tag_name, link: r.html_url };
    }
    if (src.kind === "discourse-post") {
        const t = await get(src.url, true);
        const p = t.post_stream.posts[0];
        return { value: String(p.version), link: src.page, note: "first post edited " + p.updated_at };
    }
    throw new Error("unknown kind " + src.kind);
}

(async () => {
    const changes = [];
    let failed = 0;
    for (const src of cfg.sources) {
        const mine = localValue(src);
        try {
            const up = await upstream(src);
            const changed = up.value !== src.reviewed;
            const line = (changed ? "CHANGED " : "ok      ") + src.name + ": upstream " + up.value + (changed ? " (reviewed " + src.reviewed + ")" : "") +
                (mine !== null ? ", ours " + mine : "") + (up.note ? ", " + up.note : "");
            console.log(line);
            if (changed) {
                changes.push({
                    title: "Upstream: " + src.name + " " + up.value,
                    body: [
                        "**" + src.name + "** changed upstream: `" + src.reviewed + "` -> `" + up.value + "`" + (up.note ? " (" + up.note + ")" : "") + ".",
                        "",
                        "- Why it matters: " + src.why,
                        mine !== null ? "- Our copy: `" + mine + "` (" + src.local.file + ")" : "- Nothing of it is copied in the addon.",
                        "- Upstream: " + up.link,
                        "",
                        "Next: ask Claude to compare the change with our copy (nothing is updated automatically). Once looked at, write `" +
                            up.value + "` as `reviewed` for this source in `tools/watch.json`.",
                    ].join("\n"),
                });
            }
        } catch (e) {
            failed++;
            console.log("ERROR   " + src.name + ": " + e.message);
        }
    }
    console.log(changes.length + " change(s), " + failed + " source(s) not read.");
    if (issues && changes.length) {
        // GH_BIN=fake-gh.js: a test double, run with node (never the real gh)
        const bin = process.env.GH_BIN || "gh";
        const gh = (args) => (bin.endsWith(".js") ? execFileSync(process.execPath, [bin, ...args], { encoding: "utf8" }) : execFileSync(bin, args, { encoding: "utf8" }));
        try { gh(["label", "create", "deps-watch", "--color", "5319e7", "--description", "Automatic dependency watch"]); } catch (e) { /* exists */ }
        for (const c of changes) {
            const found = JSON.parse(gh(["issue", "list", "--label", "deps-watch", "--state", "all", "--search", '"' + c.title + '" in:title', "--json", "title"]) || "[]");
            if (found.some((i) => i.title === c.title)) { console.log("Already reported: " + c.title); continue; }
            const args = ["issue", "create", "--title", c.title, "--body", c.body, "--label", "deps-watch"];
            if (process.env.OWNER) args.push("--assignee", process.env.OWNER);
            console.log(gh(args).trim());
        }
    }
    process.exit(failed || (!issues && changes.length) ? 1 : 0);
})();
