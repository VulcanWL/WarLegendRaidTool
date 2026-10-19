// Runs every case against local Ollama models (127.0.0.1 only). Per-request options only: no model / config change.
// Measures GPU energy per answer (nvidia-smi power.draw sampled every 500 ms, integrated over the request).
"use strict";
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const HOST = "http://127.0.0.1:11434";
const DIR = __dirname;
const OUTDIR = path.join(DIR, "out2");
const only = process.argv[2] ? process.argv[2].split(",") : null;

// lightest first, heaviest last
const CONFIGS = [
    { name: "gpt-oss-20b-low", model: "gpt-oss:20b", think: "low", predict: 6000 },
    { name: "qwen-wowfix-nothink", model: "qwen3.6-wowfix:latest", think: false, predict: 4000 },
    { name: "qwen-wowfix-think", model: "qwen3.6-wowfix:latest", think: true, predict: 12000 },
    // what tools/ask-local.js would do today for a big file: context capped at 32768
    { name: "qwen-askLocal-32k", model: "qwen3.6-wowfix:latest", think: false, predict: 1500, ctx: 32768, cases: ["R1"] },
];
const cases = JSON.parse(fs.readFileSync(path.join(DIR, "cases.json"), "utf8"));

// ---- power sampling
const samples = []; // [ms, watts]
const smi = spawn("C:\\Windows\\System32\\nvidia-smi.exe", ["--query-gpu=power.draw", "--format=csv,noheader,nounits", "-lms", "500"], { windowsHide: true });
let buf = "";
smi.stdout.on("data", (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf("\n")) >= 0) {
        const w = parseFloat(buf.slice(0, i));
        buf = buf.slice(i + 1);
        if (!isNaN(w)) samples.push([Date.now(), w]);
    }
});
process.on("exit", () => smi.kill());
function energyWh(t0, t1) {
    let wh = 0, prev = null;
    for (const [t, w] of samples) {
        if (t < t0) { prev = [t, w]; continue; }
        if (t > t1) break;
        const from = prev ? Math.max(prev[0], t0) : t0;
        wh += w * (t - from) / 3600000;
        prev = [t, w];
    }
    return +wh.toFixed(3);
}

async function unloadAll() {
    const ps = await (await fetch(HOST + "/api/ps")).json();
    for (const m of ps.models || []) {
        await fetch(HOST + "/api/generate", { method: "POST", body: JSON.stringify({ model: m.name, keep_alive: 0 }) });
    }
    // wait until the card really is free (a model loading while the old runner still holds VRAM crashes with CUDA 0xc0000409)
    const { execFileSync } = require("child_process");
    for (let i = 0; i < 60; i++) {
        const used = parseInt(execFileSync("C:\\Windows\\System32\\nvidia-smi.exe", ["--query-gpu=memory.used", "--format=csv,noheader,nounits"], { encoding: "utf8" }), 10);
        if (used < 2500) break;
        await new Promise((r) => setTimeout(r, 1000));
    }
    await new Promise((r) => setTimeout(r, 2000));
}

async function run(cfg, c) {
    const prompt = fs.readFileSync(path.join(DIR, "cases", c.id + ".txt"), "utf8");
    const ctx = cfg.ctx || (c.id === "R1" ? 40960 : 24576); // 65536 crashed the runner (CUDA) on a 16 GB card
    const body = { model: cfg.model, messages: [{ role: "user", content: prompt }], stream: false, think: cfg.think,
        keep_alive: "5m", options: { num_ctx: ctx, num_predict: cfg.predict } };
    const t0 = Date.now();
    const r = await fetch(HOST + "/api/chat", { method: "POST", body: JSON.stringify(body), signal: AbortSignal.timeout(1800000) });
    const j = await r.json().catch(() => ({}));
    const t1 = Date.now();
    const res = { config: cfg.name, model: cfg.model, think: cfg.think, case: c.id, ctx, ok: r.ok, error: j.error,
        wall_s: (t1 - t0) / 1000, gpu_wh: energyWh(t0, t1), prompt_tokens: j.prompt_eval_count, out_tokens: j.eval_count,
        tok_s: j.eval_count && j.eval_duration ? +(j.eval_count / (j.eval_duration / 1e9)).toFixed(1) : null,
        load_s: j.load_duration ? +(j.load_duration / 1e9).toFixed(1) : null, done_reason: j.done_reason,
        thinking_chars: ((j.message || {}).thinking || "").length, answer: (j.message || {}).content || "" };
    const od = path.join(OUTDIR, cfg.name);
    fs.mkdirSync(od, { recursive: true });
    fs.writeFileSync(path.join(od, c.id + ".json"), JSON.stringify(res, null, 2));
    if ((j.message || {}).thinking) fs.writeFileSync(path.join(od, c.id + ".thinking.txt"), j.message.thinking);
    console.log(`${cfg.name} ${c.id} ok=${r.ok} ${res.wall_s.toFixed(0)}s ${res.gpu_wh}Wh in=${res.prompt_tokens} out=${res.out_tokens} ${res.tok_s} tok/s ${res.done_reason || res.error || ""}`);
}

(async () => {
    await new Promise((r) => setTimeout(r, 1500)); // first power samples
    let loaded = null;
    for (const pass of ["short", "long"]) {
        for (const cfg of CONFIGS) {
            if (only && !only.includes(cfg.name)) continue;
            for (const c of cases) {
                if ((pass === "long") !== (c.id === "R1")) continue;
                if (cfg.cases && !cfg.cases.includes(c.id)) continue;
                const done = path.join(OUTDIR, cfg.name, c.id + ".json");
                if (fs.existsSync(done) && JSON.parse(fs.readFileSync(done, "utf8")).ok) continue; // keep good answers
                if (loaded !== cfg.model || c.id === "R1") { await unloadAll(); loaded = cfg.model; } // one model in VRAM at a time
                for (let attempt = 1; attempt <= 3; attempt++) {
                    try { await run(cfg, c); } catch (e) { console.log(`${cfg.name} ${c.id} FAILED ${e.message}`); }
                    if (!fs.existsSync(done)) break;
                    const j = JSON.parse(fs.readFileSync(done, "utf8"));
                    if (j.ok || !/terminated|CUDA/i.test(j.error || "")) break;
                    console.log(`${cfg.name} ${c.id} runner crash, retry ${attempt}`);
                    await unloadAll();
                }
            }
        }
    }
    await unloadAll(); // leave the card free
    console.log("ALL DONE");
    process.exit(0);
})();
