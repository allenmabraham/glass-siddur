#!/usr/bin/env node
// Downloads every prayer in every bundled siddur from Sefaria and writes
// Siddur/Resources/Texts/<nusach>-texts.json as { ref: PrayerLeafText }.
// The shape mirrors PrayerLeafText in Swift so the app decodes it directly.
// Usage: node Tools/fetch-texts.js [nusach...]
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "Siddur", "Resources");
const all = ["ashkenaz", "sefard", "ari", "edotHaMizrach"];
const wanted = process.argv.slice(2).length ? process.argv.slice(2) : all;
const CONCURRENCY = 4;

function leaves(node, out = []) {
  if (node.children) node.children.forEach((c) => leaves(c, out));
  else out.push(node);
  return out;
}

function flatten(text) {
  if (typeof text === "string") return [text];
  if (Array.isArray(text)) return text.flatMap(flatten);
  return [""];
}

// Mirrors SefariaClient.makeLeafText.
function makeLeaf(payload, requestedRef) {
  const he = payload.versions.find((v) => v.language === "he");
  const en = payload.versions.find((v) => v.language === "en");
  const heParas = he ? flatten(he.text) : [];
  const enParas = en ? flatten(en.text) : [];
  const count = Math.max(heParas.length, enParas.length);
  const paragraphs = [];
  for (let i = 0; i < count; i++) {
    const h = (heParas[i] || "").trim();
    const e = (enParas[i] || "").trim();
    if (!h && !e) continue;
    paragraphs.push({ index: i, hebrewHTML: h, englishHTML: e });
  }
  const last = (s) => (s || "").split(",").pop().trim();
  return {
    ref: payload.ref || requestedRef,
    heRef: payload.heRef || "",
    title: last(payload.ref || requestedRef),
    heTitle: last(payload.heRef),
    hebrewVersionTitle: he ? he.versionTitle : null,
    englishVersionTitle: en ? en.versionTitle : null,
    paragraphs,
  };
}

async function fetchLeaf(ref, attempt = 1) {
  const url = new URL("https://www.sefaria.org/api/v3/texts/" + encodeURIComponent(ref).replace(/%2C/g, ","));
  url.searchParams.append("version", "hebrew");
  url.searchParams.append("version", "english");
  url.searchParams.set("return_format", "default");
  try {
    const res = await fetch(url, { headers: { Accept: "application/json" } });
    const json = await res.json();
    if (json.error && /no text for/i.test(json.error)) {
      // Sefaria lists this node but has nothing for it: bundle an empty prayer so the app never needs the network for it.
      return makeLeaf({ ref, heRef: "", versions: [] }, ref);
    }
    if (json.error) throw new Error(json.error);
    if (!json.versions || !json.versions.length) throw new Error("no versions");
    return makeLeaf(json, ref);
  } catch (err) {
    if (attempt < 4) {
      await new Promise((r) => setTimeout(r, 1500 * attempt));
      return fetchLeaf(ref, attempt + 1);
    }
    throw err;
  }
}

async function run(nusach) {
  const index = JSON.parse(fs.readFileSync(path.join(root, "Indices", nusach + ".json"), "utf8"));
  const refs = [...new Set(leaves(index).map((l) => l.ref))];
  const outPath = path.join(root, "Texts", nusach + "-texts.json");
  const existing = fs.existsSync(outPath) ? JSON.parse(fs.readFileSync(outPath, "utf8")) : {};
  const out = { ...existing };
  const todo = refs.filter((r) => !out[r]);
  console.log(`${nusach}: ${refs.length} refs, ${todo.length} to fetch`);
  let done = 0;
  const failures = [];
  const queue = [...todo];
  await Promise.all(
    Array.from({ length: CONCURRENCY }, async () => {
      while (queue.length) {
        const ref = queue.shift();
        try {
          out[ref] = await fetchLeaf(ref);
        } catch (e) {
          failures.push(ref + " :: " + e.message);
        }
        done++;
        if (done % 50 === 0) process.stdout.write(`  ${nusach} ${done}/${todo.length}\n`);
      }
    })
  );
  // Stable key order so diffs stay readable.
  const ordered = {};
  refs.forEach((r) => { if (out[r]) ordered[r] = out[r]; });
  fs.writeFileSync(outPath, JSON.stringify(ordered));
  const bytes = fs.statSync(outPath).size;
  console.log(`${nusach}: wrote ${Object.keys(ordered).length} prayers, ${(bytes / 1e6).toFixed(2)} MB${failures.length ? ", FAILED " + failures.length : ""}`);
  failures.forEach((f) => console.log("   ! " + f));
}

(async () => {
  for (const n of wanted) await run(n);
})();
