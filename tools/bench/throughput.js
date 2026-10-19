// Throughput test: the same 12 requests (real bugs, P2 prompt, gpt-oss:20b low) sent 1 at a time, then 2 and 4 at a time.
// Measures total wall time, GPU energy, tokens/s summed. Server settings untouched: if Ollama serves one request at
// a time, the concurrent runs simply queue (that is also a result).
"use strict";
const fs = require("fs");
const { spawn, execFileSync } = require("child_process");
const MODEL = process.env.MODEL || "gpt-oss:20b";
process.argv.length = 2; // loop.js reads its own arguments at load
const { buildPrompt, cases } = require("./loop.js");
const HOST = "http://127.0.0.1:11434";
const THINK = MODEL.startsWith("gpt-oss") ? "low" : false;
const jobs = cases.filter((c) => c.kind === "debug").map((c) => buildPrompt("P2", c));

const samples = [];
const smi = spawn("C:\\Windows\\System32\\nvidia-smi.exe", ["--query-gpu=power.draw,memory.used", "--format=csv,noheader,nounits", "-lms", "500"], { windowsHide: true });
let buf = "";
smi.stdout.on("data", (d) => { buf += d; let i; while ((i = buf.indexOf("\n")) >= 0) { const [w, m] = buf.slice(0, i).split(",").map(parseFloat); buf = buf.slice(i + 1); if (!isNaN(w)) samples.push([Date.now(), w, m]); } });
const wh = (t0, t1) => { let e = 0, p = null; for (const [t, w] of samples) { if (t < t0) { p = t; continue; } if (t > t1) break; e += w * (t - Math.max(p || t0, t0)) / 3600000; p = t; } return e; };
const maxMem = (t0, t1) => Math.max(...samples.filter(([t]) => t >= t0 && t <= t1).map((s) => s[2]));

async function one(prompt) {
    const r = await fetch(HOST + "/api/chat", { method: "POST", body: JSON.stringify({ model: MODEL, messages: [{ role: "user", content: prompt }],
        stream: false, think: THINK, keep_alive: "5m", options: { num_ctx: 16384, num_predict: 3000 } }) });
    const j = await r.json();
    return j.eval_count || 0;
}
async function run(conc) {
    const queue = jobs.slice();
    let tokens = 0;
    const t0 = Date.now();
    await Promise.all(Array.from({ length: conc }, async () => { while (queue.length) tokens += await one(queue.shift()); }));
    const t1 = Date.now();
    return { conc, total_s: +((t1 - t0) / 1000).toFixed(1), wh: +wh(t0, t1).toFixed(2), out_tokens: tokens,
        tok_s: +(tokens / ((t1 - t0) / 1000)).toFixed(0), per_job_s: +((t1 - t0) / 1000 / jobs.length).toFixed(1), vram_mb: maxMem(t0, t1) };
}
(async () => {
    await new Promise((r) => setTimeout(r, 1500));
    await one("Réponds OK"); // load the model once
    for (const conc of [1, 2, 4]) console.log(JSON.stringify(await run(conc)));
    smi.kill();
    process.exit(0);
})();
