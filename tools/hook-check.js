// WarLegend RaidTool - Claude Code hook (PostToolUse on Edit / Write): after a .lua or .toc file changes, runs
// tools/check.js and shows ONLY the problems (exit 2: the message goes back to Claude). Silent when all is fine.
"use strict";
const { spawnSync } = require("child_process");
const path = require("path");
let input = "";
process.stdin.on("data", (d) => { input += d; });
process.stdin.on("end", () => {
    let file = "";
    try { file = (JSON.parse(input).tool_input || {}).file_path || ""; } catch (e) { process.exit(0); }
    if (!/\.(lua|toc)$/i.test(file)) process.exit(0);
    const r = spawnSync(process.execPath, [path.join(__dirname, "check.js")], { encoding: "utf8" });
    if (r.status === 0) process.exit(0);
    process.stderr.write("tools/check.js after editing " + path.basename(file) + ":\n" + (r.stdout || "") + (r.stderr || ""));
    process.exit(2);
});
