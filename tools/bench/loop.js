// Optimization loop for the local AI (no weights touched, nothing written to Ollama: the prompt goes with each request).
// Grid of prompt variants x model configs over: 12 real bugs fixed live (6 train / 6 test) + 6 synthetic review cases.
// Automatic grading, GPU energy per answer, results in results/<round>/ and a leaderboard.
// Usage: node loop.js <round> [prompts=P0,P1,P2] [configs=qwen-nothink,gptoss-low,...]
"use strict";
const fs = require("fs");
const path = require("path");
const { spawn, execFileSync } = require("child_process");
const HOST = "http://127.0.0.1:11434";
const DIR = __dirname;
const ROUND = process.argv[2] || "r1";
const PROMPTS_ON = (process.argv[3] || "P0,P1,P2").split(",");
const CONFIGS_ON = process.argv[4] ? process.argv[4].split(",") : null;
const RES = path.join(DIR, "results", ROUND);
fs.mkdirSync(RES, { recursive: true });

const CONFIGS = {
    "qwen-nothink": { model: "qwen3.6-wowfix:latest", think: false, predict: 2500 },
    "qwen-think": { model: "qwen3.6-wowfix:latest", think: true, predict: 8000 },
    "gptoss-low": { model: "gpt-oss:20b", think: "low", predict: 3000 },
    "gptoss-med": { model: "gpt-oss:20b", think: "medium", predict: 6000 },
    "gptoss-high": { model: "gpt-oss:20b", think: "high", predict: 10000 },
};

// ---------------- prompts ----------------
const RULES = `Contexte : addon World of Warcraft Classic "WarLegendRaidTool" (Lua 5.1 de WoW).
Règles du projet : Lua 5.1 (pas de goto, //, opérateurs bit à bit, table.unpack). Ne jamais inventer d'API WoW.
Frames sécurisées : rien en combat sans tester InCombatLockdown(). Fichier : local W = WLRT ; local L = W.L ; local db.
Données : W.OnReady(function() db = W.DB("cle", { défauts scalaires }) end). Événements : W.On("EVENT", fn, always, inactive)
(inactive = true : démarre éteint, W.Activate(h, on) l'allume ; always = true : tourne même hors guilde, réservé au cœur).
Textes : L("English") est une fonction (jamais L["..."]) ; le français peut être dans Locale.lua ou W.AddFR.
Réponds en français.`;

const FORMAT_DEBUG = `Réponds UNIQUEMENT dans ce format, sans montrer ta réflexion, 200 mots maximum :
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

const CAUTION = `Avant de répondre, vérifie chaque point : ne signale pas ce que le code gère déjà (gardes "if X and X()", pcall,
tests de nil). Les fonctions wipe, unpack, issecretvalue, issecret, pcall, C_Timer existent dans ce client.`;

// Catalogue written ONLY from the train bugs (L1, L2, L6, L8, L10, L11) and AGENTS.md
const CATALOGUE = `Bugs déjà rencontrés dans ce projet (à vérifier en priorité) :
1. Fonction "local" utilisée plus haut que sa déclaration : à l'endroit de l'appel c'est une globale nil
   ("attempt to call global 'X' (a nil value)"). Corriger en déplaçant la déclaration au-dessus des fonctions qui l'appellent.
2. Valeurs secrètes (ce client WoW) : UnitPower, UnitPowerMax, GetRaidTargetIndex, IsVisible, GetWidth, les auras... peuvent
   renvoyer une valeur secrète. Une valeur secrète ne peut être ni testée (if v, v and, not v), ni comparée (==, ~=, <),
   ni servir d'index de table : erreur. Toujours tester issecretvalue(v) / issecret(v) EN PREMIER, avant tout autre test ;
   pour savoir si elle est nil : type(v) == "nil".
3. Une erreur avalée (SafeCall, pcall) donne un symptôme "figé, sans erreur" : chercher une opération qui lève une erreur
   au début de la fonction de mise à jour.
4. La liste de guilde de Classic peut ne contenir que les membres connectés : un membre absent de la liste n'a pas forcément
   quitté la guilde.
5. Chaque fonctionnalité doit tester SA propre option (db.queue, db.flag...), pas celle d'une autre (db.enabled).
6. Un état perdu puis retrouvé (mort puis résurrection, caché puis montré) a besoin d'un traitement de l'événement de retour
   (UnitRevived...), pas seulement de l'événement de perte.
Méthode : relie le symptôme à la ligne exacte qui le produit, puis vérifie pour chaque valeur venant du jeu (API, événement) :
peut-elle être nil, secrète, ou appartenir à une autre unité / un autre joueur ? L'ordre de chargement et de déclaration
est-il bon ?`;

// P3: the catalogue as known traps, not a checklist (round 1: P2 made the model see secret values everywhere in review)
const SCOPE = `Ce catalogue liste des pièges connus, ce n'est pas une liste à appliquer partout : signale un piège seulement si tu
vois la ligne exacte qui le déclenche. Seules les valeurs venant des API citées au point 2 (ou d'une erreur qui dit "secret")
peuvent être secrètes. En relecture sans symptôme : 3 bugs maximum, uniquement ceux dont tu es sûr.`;

function buildPrompt(variant, c) {
    variant = variant.replace(/V$/, ""); // the V suffix = same prompt + a verification pass
    const isReview = c.kind === "review";
    const task = isReview
        ? `Tâche : relis ce code et liste les vrais bugs.\n\n${c.code}`
        : `Symptôme signalé en jeu : ${c.symptom}\n\nCode (fichier ${c.file}, avant correction) :\n${c.code}\n\nTâche : trouve la cause de ce bug et propose le correctif.`;
    const parts = [RULES];
    if (variant === "P2" || variant === "P3") parts.push(CATALOGUE);
    if (variant === "P3") parts.push(SCOPE);
    parts.push(task);
    if (variant !== "P0") parts.push(CAUTION, isReview ? FORMAT_REVIEW : FORMAT_DEBUG);
    else if (isReview) parts.push(`Pour chaque bug : ligne, explication, correction. Si le code est correct, réponds "Aucun bug trouvé".`);
    return parts.join("\n\n");
}

function verifyPrompt(c, claim) {
    return `${RULES}\n\nCode :\n${c.code}\n\n` + (c.symptom ? `Symptôme signalé : ${c.symptom}\n\n` : "") +
        `Quelqu'un affirme :\n${claim.slice(0, 1200)}\n\nRelis la ligne citée et les lignes autour, dans CE code. Cette affirmation ` +
        `est-elle un bug réel et certain (pas une hypothèse, pas déjà géré par une garde ou un pcall, pas une API inventée) ?\n` +
        `Réponds par OUI ou NON en premier mot, puis une seule phrase.`;
}

// ---------------- cases ----------------
const cases = [];
for (const f of fs.readdirSync(path.join(DIR, "real")).sort()) {
    const r = JSON.parse(fs.readFileSync(path.join(DIR, "real", f), "utf8"));
    cases.push({ id: r.id, kind: "debug", split: r.split, symptom: r.symptom, code: r.code, file: r.file,
        expect: [{ lines: r.expect.lines, kw: new RegExp(r.expect.kw, r.expect.kwFlags) }] });
}
// synthetic review cases from the first benchmark (code part only, same seeded bugs)
const SYN = {
    B1: [{ lines: [26], kw: /(\/\/|math\.floor)/ }, { lines: [59], kw: /(encounterEnd|ENCOUNTER_END|invers|not isEncounter)/i }],
    B2: [{ lines: [82, 74], kw: /(inactive|always|nil, true)/i }, { lines: [80], kw: /(wbAt|mark|==)/ }],
    B3: [{ lines: [33, 32], kw: /InCombatLockdown/ }, { lines: [75], kw: /(L\(|L\[)/ }],
    B4: [{ lines: [80, 81], kw: /(global|portée|scope|déclar|local box\s*$|local box\n|avant)/im }, { lines: [91], kw: /(#ranks \+ 1|dernier|last|off)/i }],
    B5: [{ lines: [147], kw: /(select|#t|trou|nil)/i }, { lines: [153], kw: /(\*|vide|empty|\+)/i }],
    B6: [],
};
for (const id of Object.keys(SYN)) {
    const txt = fs.readFileSync(path.join(DIR, "cases", id + ".txt"), "utf8");
    const code = txt.slice(txt.search(/\n(Fichier|Extrait) [^\n]*:\n/) + 1);
    cases.push({ id, kind: "review", split: "test", code, expect: SYN[id] });
}
// sealed set: only with HOLDOUT=1 (final measurement)
if (process.env.HOLDOUT === "1") {
    for (const f of fs.readdirSync(path.join(DIR, "holdout")).sort()) {
        const h = JSON.parse(fs.readFileSync(path.join(DIR, "holdout", f), "utf8"));
        const ex = (e) => ({ lines: e.lines, kw: new RegExp(e.kw, e.kwFlags) });
        cases.push({ id: h.id, kind: h.kind, split: "holdout", symptom: h.symptom, code: h.code, file: h.file,
            expect: Array.isArray(h.expect) ? h.expect.map(ex) : [ex(h.expect)] });
    }
}

// ---------------- grading ----------------
const lineRe = (n) => new RegExp("(lignes?|line|\\bL)\\s*\\.?\\s*(\\d+\\s*[-–à,et ]+\\s*)*" + n + "\\b|\\b" + n + ":", "i");
function blocks(answer, kind) {
    const re = kind === "review" ? /^\s*\**\s*(BUG\s*\d+)/gim : /^\s*\**\s*(CAUSE\s*\d+)/gim;
    const idx = [];
    let m;
    while ((m = re.exec(answer))) idx.push(m.index);
    if (!idx.length) return null;
    return idx.map((s, i) => answer.slice(s, idx[i + 1] === undefined ? answer.length : idx[i + 1]));
}
function hits(text, e) {
    const near = [];
    for (const n of e.lines) for (const d of [-1, 0, 1]) near.push(n + d);
    return near.some((n) => lineRe(n).test(text)) && e.kw.test(text);
}
function grade(c, answer) {
    const b = blocks(answer, c.kind);
    if (c.kind === "debug") {
        const e = c.expect[0];
        if (b) return { score: hits(b[0], e) ? 1 : b.slice(1).some((x) => hits(x, e)) ? 0.5 : 0, structured: true };
        return { score: hits(answer.slice(0, 1500), e) ? 1 : hits(answer, e) ? 0.5 : 0, structured: false };
    }
    // review
    if (/^\s*\**\s*(AUCUN BUG|Aucun bug trouvé)/im.test(answer) && !b) {
        return { found: 0, expected: c.expect.length, fp: 0, structured: true };
    }
    if (b) {
        const used = new Set();
        let fp = 0;
        for (const x of b) {
            const k = c.expect.findIndex((e, i) => !used.has(i) && hits(x, e));
            if (k >= 0) used.add(k); else fp++;
        }
        return { found: used.size, expected: c.expect.length, fp, structured: true };
    }
    const found = c.expect.filter((e) => hits(answer, e)).length;
    return { found, expected: c.expect.length, fp: null, structured: false };
}

module.exports = { grade, cases, buildPrompt };
if (require.main !== module) return;

// ---------------- power + ollama ----------------
const samples = [];
const smi = spawn("C:\\Windows\\System32\\nvidia-smi.exe", ["--query-gpu=power.draw", "--format=csv,noheader,nounits", "-lms", "500"], { windowsHide: true });
let buf = "";
smi.stdout.on("data", (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf("\n")) >= 0) { const w = parseFloat(buf.slice(0, i)); buf = buf.slice(i + 1); if (!isNaN(w)) samples.push([Date.now(), w]); }
});
process.on("exit", () => smi.kill());
function energyWh(t0, t1) {
    let wh = 0, prev = null;
    for (const [t, w] of samples) {
        if (t < t0) { prev = [t, w]; continue; }
        if (t > t1) break;
        wh += w * (t - (prev ? Math.max(prev[0], t0) : t0)) / 3600000;
        prev = [t, w];
    }
    return wh;
}
async function unloadAll() {
    const ps = await (await fetch(HOST + "/api/ps")).json();
    for (const m of ps.models || []) await fetch(HOST + "/api/generate", { method: "POST", body: JSON.stringify({ model: m.name, keep_alive: 0 }) });
    for (let i = 0; i < 60; i++) {
        const used = parseInt(execFileSync("C:\\Windows\\System32\\nvidia-smi.exe", ["--query-gpu=memory.used", "--format=csv,noheader,nounits"], { encoding: "utf8" }), 10);
        if (used < 2500) break;
        await new Promise((r) => setTimeout(r, 1000));
    }
    await new Promise((r) => setTimeout(r, 2000));
}
async function ask(cfg, prompt) {
    const body = { model: cfg.model, messages: [{ role: "user", content: prompt }], stream: false, think: cfg.think,
        keep_alive: "5m", options: { num_ctx: 16384, num_predict: cfg.predict, temperature: 0.2 } }; // as ask-local.js
    for (let attempt = 1; attempt <= 3; attempt++) {
        const t0 = Date.now();
        const r = await fetch(HOST + "/api/chat", { method: "POST", body: JSON.stringify(body), signal: AbortSignal.timeout(1200000) });
        const j = await r.json().catch(() => ({}));
        const t1 = Date.now();
        if (!r.ok && /terminated|CUDA/i.test(j.error || "") && attempt < 3) { await unloadAll(); continue; }
        return { ok: r.ok, error: j.error, wall_s: (t1 - t0) / 1000, wh: energyWh(t0, t1), in: j.prompt_eval_count,
            out: j.eval_count, done: j.done_reason, thinking: (j.message || {}).thinking || "", answer: (j.message || {}).content || "" };
    }
}

// ---------------- main ----------------
(async () => {
    await new Promise((r) => setTimeout(r, 1500));
    let loaded = null;
    const board = [];
    for (const cname of Object.keys(CONFIGS)) {
        if (CONFIGS_ON && !CONFIGS_ON.includes(cname)) continue;
        const cfg = CONFIGS[cname];
        for (const pv of PROMPTS_ON) {
            const cell = `${pv}__${cname}`;
            const od = path.join(RES, cell);
            fs.mkdirSync(od, { recursive: true });
            for (const c of cases) {
                const f = path.join(od, c.id + ".json");
                if (fs.existsSync(f) && JSON.parse(fs.readFileSync(f, "utf8")).ok) continue;
                if (loaded !== cfg.model) { await unloadAll(); loaded = cfg.model; }
                const res = await ask(cfg, buildPrompt(pv, c));
                if (res.ok && pv.endsWith("V")) {
                    // verification pass: each claim is checked by a short call (no thinking), the rejected ones are dropped
                    const b = blocks(res.answer, c.kind);
                    if (b && b.length) {
                        const vcfg = Object.assign({}, cfg, { think: cfg.model.startsWith("gpt-oss") ? "low" : false, predict: 300 });
                        const kept = [];
                        res.verify = [];
                        for (const claim of b.slice(0, 5)) {
                            const v = await ask(vcfg, verifyPrompt(c, claim));
                            res.wh += v.wh; res.wall_s += v.wall_s; res.out = (res.out || 0) + (v.out || 0);
                            const yes = /^\W*OUI/i.test(v.answer || "");
                            res.verify.push({ yes, answer: v.answer });
                            if (yes) kept.push(claim);
                        }
                        res.raw_answer = res.answer;
                        const tag = c.kind === "review" ? "BUG" : "CAUSE";
                        res.answer = kept.length ? kept.map((k, i) => k.replace(/^\s*\**\s*(BUG|CAUSE)\s*\d+/i, tag + " " + (i + 1))).join("\n")
                            : (c.kind === "review" ? "AUCUN BUG" : "CAUSE 1: aucune cause confirmée");
                    }
                }
                res.grade = res.ok ? grade(c, res.answer) : null;
                res.case = c.id; res.split = c.split; res.kind = c.kind;
                fs.writeFileSync(f, JSON.stringify(res, null, 2));
            }
            // cell summary
            const rows = cases.map((c) => JSON.parse(fs.readFileSync(path.join(od, c.id + ".json"), "utf8")));
            const dbg = (split) => rows.filter((r) => r.kind === "debug" && r.split === split && r.grade);
            const rev = rows.filter((r) => r.kind === "review" && r.grade && r.split !== "holdout");
            const hold = rows.filter((r) => r.split === "holdout" && r.grade);
            const sum = (a, f) => a.reduce((s, r) => s + f(r), 0);
            const s = {
                cell, prompt: pv, config: cname,
                train: +(sum(dbg("train"), (r) => r.grade.score) / 6).toFixed(2),
                test: +(sum(dbg("test"), (r) => r.grade.score) / 6).toFixed(2),
                review_recall: +(sum(rev, (r) => r.grade.found) / 10).toFixed(2),
                review_fp: rev.every((r) => r.grade.fp !== null) ? sum(rev, (r) => r.grade.fp) : "n/a",
                b6_clean: (rev.find((r) => r.case === "B6") || {}).grade ? rev.find((r) => r.case === "B6").grade.fp === 0 && rev.find((r) => r.case === "B6").grade.found === 0 : null,
                holdout: hold.length ? {
                    debug: +(sum(hold.filter((r) => r.kind === "debug"), (r) => r.grade.score) / 3).toFixed(2),
                    review_found: sum(hold.filter((r) => r.kind === "review"), (r) => r.grade.found) + "/2",
                    review_fp: sum(hold.filter((r) => r.kind === "review"), (r) => r.grade.fp || 0),
                } : undefined,
                errors: rows.filter((r) => !r.ok).length,
                wh_per_case: +(sum(rows, (r) => r.wh || 0) / rows.length).toFixed(3),
                out_tokens_per_case: Math.round(sum(rows, (r) => r.out || 0) / rows.length),
                sec_per_case: +(sum(rows, (r) => r.wall_s || 0) / rows.length).toFixed(1),
                truncated: rows.filter((r) => r.done === "length").length,
            };
            board.push(s);
            fs.appendFileSync(path.join(RES, "leaderboard.jsonl"), JSON.stringify(s) + "\n");
            console.log(JSON.stringify(s));
        }
    }
    await unloadAll();
    console.log("ALL DONE");
    process.exit(0);
})();
