// WarLegend RaidTool - ask the local AI (Ollama on this PC) for simple text work, to save Claude tokens (not shipped).
// Usage: node tools/ask-local.js [options] "instruction" [--file path ...]   (the instruction can also come on stdin)
//   --file path   add a file to the prompt: the script reads it, so the caller never has to (repeatable)
//   --bug "text"  diagnose a bug from its symptom (in-game error or behaviour) in the --file(s): project rules, the
//                 catalogue of bugs already met (tools/local-ai-catalogue.md) and a short "CAUSE 1: ligne N" answer
//   --review      look for bugs in the --file(s) without a symptom (weak: few bugs found, use as a hint only)
//   --each        one separate question per --file (a batch: the answers come one after the other)
//   --model name  default gpt-oss:20b (12.8 GB, all on the graphics card, reads 64k tokens); the benchmark of
//                 2026-10-18 found no better local model for this project on a 16 GB card
//   --gpu N|all   layers on the graphics card. Default while WoW runs: as many as fit in the free video memory minus
//                 --reserve (the rest on the CPU); else all
//   --reserve MB  video memory left free for the game while it runs (default 4096)
//   --threads N   CPU threads. Default: 3 while WoW runs (of the 8), else Ollama's choice
//   --max N       max answer tokens (default 1500)
//   --unload      free the model's memory now (it is also freed by itself 2 minutes after the last question)
// Only 127.0.0.1 is ever contacted: nothing leaves the PC. Starts "ollama serve" (below-normal priority, one model,
// one request at a time) when it is not running, and stops it again (with its model runners) when the script ends.
// Programs are run by full path, never looked up in the current folder. Prints only the answer; one status line goes
// to stderr, and a warning there when the model did not read the whole prompt (Ollama cuts it silently).
// Good for: French drafts of L() strings, summaries of long logs / diffs / files, prose drafts, a first diagnosis with
// --bug (right about one time in two on bugs it has never seen, the fix often wrong: check both). Never for WoW API or
// design decisions.
// A bug fixed live that the local AI missed: add its lesson to tools/local-ai-catalogue.md (one numbered line).
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn, execFileSync } = require("child_process");

const HOST = "http://127.0.0.1:11434";
const GAME_EXE = /^"Wow(Classic)?[BT]?\.exe"/im; // Wow.exe, WowB.exe (beta), WowClassic.exe... not WowUp / WowVoiceProxy
const SYS32 = path.join(process.env.SystemRoot || "C:\\Windows", "System32");
const CATALOGUE = path.join(__dirname, "local-ai-catalogue.md");

// Full path of a program: the known places first, then the absolute folders of PATH. Never the current folder (Windows
// would run an exe found there first), never a relative PATH entry. null when not found.
function findExe(name, known) {
    const cwd = path.resolve(process.cwd()).toLowerCase();
    const dirs = (process.env.PATH || "").split(path.delimiter)
        .map((d) => d.trim().replace(/^"(.*)"$/, "$1"))
        .filter((d) => d && path.isAbsolute(d) && path.resolve(d).toLowerCase() !== cwd);
    const candidates = known.filter((p) => p && path.isAbsolute(p)).concat(dirs.map((d) => path.join(d, name)));
    return candidates.find((p) => fs.existsSync(p)) || null;
}

// "ollama serve" started by this script (null when it was already running): stopped with its runners on exit
let server = null;
function stopServer() {
    if (!server) return;
    const pid = server.pid;
    server = null;
    try {
        execFileSync(path.join(SYS32, "taskkill.exe"), ["/PID", String(pid), "/T", "/F"], { stdio: "ignore", windowsHide: true });
    } catch (e) { /* already gone */ }
}
process.on("exit", stopServer); // also runs after fail() and uncaught errors
process.on("SIGINT", () => process.exit(130));

function fail(msg) {
    process.stderr.write("ask-local: " + msg + "\n");
    process.exit(1);
}

const args = { files: [], model: "gpt-oss:20b", gpu: null, reserve: 4096, threads: null, max: 1500, unload: false, text: [],
    bug: null, review: false, each: false };
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--file") args.files.push(argv[++i]);
    else if (a === "--bug") args.bug = argv[++i];
    else if (a === "--review") args.review = true;
    else if (a === "--each") args.each = true;
    else if (a === "--model") args.model = argv[++i];
    else if (a === "--gpu") args.gpu = argv[++i];
    else if (a === "--reserve") args.reserve = parseInt(argv[++i], 10);
    else if (a === "--threads") args.threads = parseInt(argv[++i], 10);
    else if (a === "--max") args.max = parseInt(argv[++i], 10);
    else if (a === "--unload") args.unload = true;
    else args.text.push(a);
}

// ---- prompts for --bug / --review (the best ones of the 2026-10-18 benchmark: rules + catalogue + short format)
const RULES = `Contexte : addon World of Warcraft Classic "WarLegendRaidTool" (Lua 5.1 de WoW).
Règles du projet : Lua 5.1 (pas de goto, //, opérateurs bit à bit, table.unpack). Ne jamais inventer d'API WoW.
Frames sécurisées : rien en combat sans tester InCombatLockdown(). Fichier : local W = WLRT ; local L = W.L ; local db.
Données : W.OnReady(function() db = W.DB("cle", { défauts scalaires }) end). Événements : W.On("EVENT", fn, always, inactive)
(inactive = true : démarre éteint, W.Activate(h, on) l'allume ; always = true : tourne même hors guilde, réservé au cœur).
Textes : L("English") est une fonction (jamais L["..."]) ; le français peut être dans Locale.lua ou W.AddFR.
Réponds en français.`;
const CAUTION = `Avant de répondre, vérifie chaque point : ne signale pas ce que le code gère déjà (gardes "if X and X()", pcall,
tests de nil). Les fonctions wipe, unpack, issecretvalue, issecret, pcall, C_Timer existent dans ce client.`;
const FORMAT_BUG = `Réponds UNIQUEMENT dans ce format, sans montrer ta réflexion, 200 mots maximum :
CAUSE 1: ligne <N> — <la cause en une ou deux phrases>
CORRECTIF:
\`\`\`lua
<le code corrigé des lignes concernées>
\`\`\`
CAUSE 2: ligne <N> — <seulement si une deuxième cause est vraiment plausible>`;
const FORMAT_REVIEW = `Réponds UNIQUEMENT dans ce format, sans montrer ta réflexion, 300 mots maximum :
BUG 1: ligne <N> — <le problème en une ou deux phrases> | CORRECTIF: <code>
BUG 2: ...
ou, s'il n'y a aucun vrai bug : AUCUN BUG
Ne liste que des bugs certains (plantage, comportement faux, règle du projet violée), jamais du style ni des hypothèses.`;

// a file's text for the prompt: numbered lines in --bug / --review (the answer cites them)
function fileBlock(f) {
    if (!fs.existsSync(f)) fail("file not found: " + f);
    let src = fs.readFileSync(f, "utf8");
    if (args.bug !== null || args.review) {
        src = src.replace(/\r\n/g, "\n").split("\n").map((l, i) => String(i + 1).padStart(4) + ": " + l).join("\n");
    }
    return "\n\n----- " + path.basename(f) + " -----\n" + src;
}

function buildPrompt(text, files) {
    const code = files.map(fileBlock).join("");
    if (args.bug === null && !args.review) return text + code;
    const catalogue = fs.existsSync(CATALOGUE) ? fs.readFileSync(CATALOGUE, "utf8").trim() : "";
    const task = args.bug !== null
        ? "Symptôme signalé en jeu : " + args.bug + (text ? "\n" + text : "") + "\n\nCode :" + code +
            "\n\nTâche : trouve la cause de ce bug et propose le correctif."
        : (text ? text + "\n\n" : "") + "Tâche : relis ce code et liste les vrais bugs.\n\nCode :" + code;
    return [RULES, catalogue, task, CAUTION, args.bug !== null ? FORMAT_BUG : FORMAT_REVIEW].filter(Boolean).join("\n\n");
}

function gameRunning() {
    try {
        return GAME_EXE.test(execFileSync(path.join(SYS32, "tasklist.exe"), ["/NH", "/FO", "CSV"], { encoding: "utf8", windowsHide: true }));
    } catch (e) {
        return false;
    }
}

// layers of the model that fit in the free video memory minus the game's reserve (0 when unknown)
async function gpuLayers(model) {
    try {
        const smi = findExe("nvidia-smi.exe", [path.join(SYS32, "nvidia-smi.exe"),
            path.join(process.env.ProgramFiles || "C:\\Program Files", "NVIDIA Corporation", "NVSMI", "nvidia-smi.exe")]);
        if (!smi) return 0;
        let free = parseInt(execFileSync(smi, ["--query-gpu=memory.free", "--format=csv,noheader,nounits"],
            { encoding: "utf8", windowsHide: true }), 10);
        // a model still loaded holds video memory that this question would reuse
        const ps = await (await fetch(HOST + "/api/ps")).json();
        for (const x of ps.models || []) free += (x.size_vram || 0) / 1048576;
        const show = await (await fetch(HOST + "/api/show", { method: "POST", body: JSON.stringify({ model }) })).json();
        const info = show.model_info || {};
        const blocks = info[info["general.architecture"] + ".block_count"];
        const tags = await (await fetch(HOST + "/api/tags")).json();
        const m = (tags.models || []).find((x) => x.name === model || x.model === model);
        if (!free || !blocks || !m) return 0;
        const perLayer = m.size / 1048576 / (blocks + 1); // MiB, the output layer counted as one more
        const budget = free - args.reserve - 1200; // 1.2 GB for the context and the work buffers
        return Math.max(0, Math.min(blocks, Math.floor(budget / perLayer)));
    } catch (e) {
        return 0;
    }
}

async function up() {
    try {
        const r = await fetch(HOST + "/api/version", { signal: AbortSignal.timeout(1500) });
        return r.ok;
    } catch (e) {
        return false;
    }
}

function ollamaExe() {
    const local = process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Programs", "Ollama", "ollama.exe") : null;
    return findExe("ollama.exe", [local]) || fail("ollama.exe not found (installed in %LOCALAPPDATA%\\Programs\\Ollama or on PATH?)");
}

async function ensureServer() {
    if (await up()) return;
    const env = Object.assign({}, process.env, {
        OLLAMA_HOST: "127.0.0.1:11434", // local only
        OLLAMA_KEEP_ALIVE: "2m", // memory freed 2 minutes after the last question
        OLLAMA_MAX_LOADED_MODELS: "1",
        OLLAMA_NUM_PARALLEL: "1",
    });
    const child = spawn(ollamaExe(), ["serve"], { env, stdio: "ignore", windowsHide: true });
    child.on("error", (e) => fail("cannot start ollama: " + e.message));
    if (child.pid) server = child;
    try {
        os.setPriority(child.pid, os.constants.priority.PRIORITY_BELOW_NORMAL); // its model runners inherit it
    } catch (e) { /* the server still works at normal priority */ }
    child.unref(); // the script does not wait for it: stopServer() ends it on exit
    for (let i = 0; i < 40; i++) {
        await new Promise((r) => setTimeout(r, 500));
        if (await up()) return;
    }
    fail("ollama serve did not answer on 127.0.0.1:11434");
}

async function readStdin() {
    if (process.stdin.isTTY) return "";
    let s = "";
    for await (const chunk of process.stdin) s += chunk;
    return s;
}

// one question to the model; prints its answer (with a title in --each)
async function ask(prompt, title, gaming) {
    const options = { temperature: 0.2, num_predict: args.max };
    // context sized to the prompt (about 3.5 characters a token), so a short question does not reserve memory;
    // gpt-oss:20b keeps 64k tokens on the 16 GB card (measured), more is cut by Ollama without any error. While WoW
    // runs, 32k at most: a bigger context would take video memory from the game
    const estimate = Math.ceil(prompt.length / 3.5);
    options.num_ctx = Math.min(gaming ? 32768 : 65536, Math.max(4096, Math.ceil(estimate * 1.2) + args.max));
    if (args.gpu === "all") { /* Ollama's choice */ }
    else if (args.gpu !== null) options.num_gpu = parseInt(args.gpu, 10);
    else if (gaming) options.num_gpu = await gpuLayers(args.model);
    if (args.threads) options.num_thread = args.threads;
    else if (gaming) options.num_thread = 3;

    const body = { model: args.model, prompt, stream: false, keep_alive: "2m", options };
    body.think = args.model.startsWith("gpt-oss") ? "low" : false; // short reasoning: faster answer
    const t0 = Date.now();
    let r = await fetch(HOST + "/api/generate", { method: "POST", body: JSON.stringify(body), signal: AbortSignal.timeout(600000) });
    if (r.status === 400) { // a model without the "think" switch
        delete body.think;
        r = await fetch(HOST + "/api/generate", { method: "POST", body: JSON.stringify(body), signal: AbortSignal.timeout(600000) });
    }
    let j = await r.json().catch(() => ({}));
    if (!r.ok && /terminated|CUDA/i.test(j.error || "")) { // the model runner crashed while (re)loading: once more
        r = await fetch(HOST + "/api/generate", { method: "POST", body: JSON.stringify(body), signal: AbortSignal.timeout(600000) });
        j = await r.json().catch(() => ({}));
    }
    if (!r.ok) fail("ollama: " + (j.error || r.status));
    if (title) process.stdout.write("===== " + title + "\n");
    process.stdout.write((j.response || "").trim() + "\n");
    // Ollama drops the start of a prompt longer than the context and says nothing: tell the caller
    if (j.prompt_eval_count && j.prompt_eval_count < estimate * 0.6) {
        process.stderr.write("ask-local: WARNING only " + j.prompt_eval_count + " of about " + estimate +
            " prompt tokens were read: the start was probably cut, ask about a smaller part\n");
    }
    const secs = (Date.now() - t0) / 1000;
    const tps = j.eval_count && j.eval_duration ? (j.eval_count / (j.eval_duration / 1e9)).toFixed(1) : "?";
    process.stderr.write("ask-local: " + args.model + (title ? " [" + title + "]" : "") + ", " + (gaming ? "WoW running: " : "") +
        "gpu " + (options.num_gpu === undefined ? "all" : options.num_gpu) + ", threads " + (options.num_thread || "auto") +
        ", " + secs.toFixed(0) + " s, " + tps + " tok/s\n");
}

async function main() {
    await ensureServer();
    if (args.unload) {
        await fetch(HOST + "/api/generate", { method: "POST", body: JSON.stringify({ model: args.model, keep_alive: 0 }) });
        process.stderr.write("ask-local: " + args.model + " unloaded\n");
        return;
    }
    let text = args.text.join(" ").trim();
    const stdin = (await readStdin()).trim();
    if (stdin) text = text ? text + "\n\n" + stdin : stdin;
    if (!text && !args.files.length && args.bug === null) fail('no instruction (usage: node tools/ask-local.js "instruction" [--file path])');
    if ((args.bug !== null || args.review || args.each) && !args.files.length) fail("--bug, --review and --each need --file");

    const gaming = gameRunning();
    if (args.each) {
        for (const f of args.files) await ask(buildPrompt(text, [f]), path.basename(f), gaming);
    } else {
        await ask(buildPrompt(text, args.files), null, gaming);
    }
}

main().catch((e) => fail(e.message));
