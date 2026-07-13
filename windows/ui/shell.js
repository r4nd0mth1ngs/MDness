// MDness Windows shell: toolbar actions, live preview, file I/O and export.
// The Markdown->HTML->Mermaid rendering is the shared vendor/app.js pipeline
// (window.mdnessRender / window.__mdnessRenderComplete); this file is only the
// native glue the SwiftUI/GTK shells provide on the other platforms.
"use strict";

// Access window.__TAURI__ lazily (inside handlers), never at top level: with
// withGlobalTauri it isn't populated yet while this script's top-level code runs
// (tauri#12990). These wrappers only touch it when a button is clicked.
const invoke = (cmd, args) => window.__TAURI__.core.invoke(cmd, args);
const openDialog = (opts) => window.__TAURI__.dialog.open(opts);
const saveDialog = (opts) => window.__TAURI__.dialog.save(opts);

const editor = document.getElementById("editor");
const content = document.getElementById("content");
const rawBtn = document.getElementById("raw");
const fmtBtn = document.getElementById("formatted");

const MD_FILTER = { name: "Markdown", extensions: ["md", "markdown", "mdown", "mkd"] };

let currentPath = null;
let modified = false;
let debounce = 0;

function baseName(p) { return p ? p.split(/[\\/]/).pop() : "Untitled"; }
function docTitle() { return baseName(currentPath).replace(/\.[^.]+$/, ""); }

function setTitle() {
  document.title = (modified ? "● " : "") + baseName(currentPath) + " — MDness";
}

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// -- view toggle --
function showFormatted(on) {
  fmtBtn.classList.toggle("active", on);
  rawBtn.classList.toggle("active", !on);
  editor.hidden = on;
  content.hidden = !on;
  if (on) window.mdnessRender(editor.value);
}
rawBtn.onclick = () => showFormatted(false);
fmtBtn.onclick = () => showFormatted(true);

editor.addEventListener("input", () => {
  modified = true;
  setTitle();
  if (!content.hidden) {
    clearTimeout(debounce);
    debounce = setTimeout(() => window.mdnessRender(editor.value), 250);
  }
});

// -- file ops --
function loadDocument(path, text) {
  currentPath = path;
  editor.value = text;
  modified = false;
  setTitle();
  if (!content.hidden) window.mdnessRender(text);
}

async function doNew() { loadDocument(null, ""); }

async function doOpen() {
  const path = await openDialog({ filters: [MD_FILTER], multiple: false });
  if (!path) return;
  try {
    loadDocument(path, await invoke("read_file", { path }));
  } catch (e) { alert("Could not open file: " + e); }
}

async function writeTo(path) {
  try {
    await invoke("write_file", { path, contents: editor.value });
    currentPath = path;
    modified = false;
    setTitle();
  } catch (e) { alert("Could not save file: " + e); }
}

async function doSave() {
  if (currentPath) return writeTo(currentPath);
  return doSaveAs();
}

async function doSaveAs() {
  const path = await saveDialog({ defaultPath: docTitle() + ".md", filters: [MD_FILTER] });
  if (path) await writeTo(path);
}

// -- export --
// Render the current text and wait for markdown-it + Mermaid to settle, mirroring
// the offscreen-poll the macOS/Linux exporters do before capturing/printing.
function renderForExport() {
  return new Promise((resolve) => {
    window.mdnessRender(editor.value);
    const start = Date.now();
    (function poll() {
      if (window.__mdnessRenderComplete || Date.now() - start > 15000) resolve();
      else setTimeout(poll, 50);
    })();
  });
}

async function exportHtml() {
  const path = await saveDialog({
    defaultPath: docTitle() + ".html",
    filters: [{ name: "HTML", extensions: ["html"] }],
  });
  if (!path) return;
  await renderForExport();
  const css = await (await fetch("vendor/mdness.css")).text();
  // Same self-contained page shape as export_page() in linux/mdness: inlined
  // CSS, baked-in SVG diagrams, no scripts. Strip the live `hidden` attribute.
  const page =
    '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n' +
    "<title>" + escapeHtml(docTitle()) + "</title>\n<style>\n" + css + "\n</style>\n" +
    '</head>\n<body>\n<article id="content">' + content.innerHTML + "</article>\n</body>\n</html>\n";
  try {
    await invoke("write_file", { path, contents: page });
  } catch (e) { alert("Could not export HTML: " + e); }
}

// PDF: route through WebView2's print pipeline ("Microsoft Print to PDF" /
// "Save as PDF"). @media print in shell.css hides the chrome so only #content
// prints. ponytail: uses the built-in print dialog, not silent file output like
// mac/Linux; wire WebView2 PrintToPdfAsync via a Rust command if silent export
// is needed later.
async function exportPdf() {
  showFormatted(true);
  await renderForExport();
  window.print();
}

document.getElementById("new").onclick = doNew;
document.getElementById("open").onclick = doOpen;
document.getElementById("save").onclick = doSave;
document.getElementById("export-html").onclick = exportHtml;
document.getElementById("export-pdf").onclick = exportPdf;

window.addEventListener("keydown", (e) => {
  if (!(e.ctrlKey || e.metaKey)) return;
  const k = e.key.toLowerCase();
  if (k === "n") { e.preventDefault(); doNew(); }
  else if (k === "o") { e.preventDefault(); doOpen(); }
  else if (k === "s") { e.preventDefault(); e.shiftKey ? doSaveAs() : doSave(); }
  else if (k === "p" && e.shiftKey) { e.preventDefault(); showFormatted(content.hidden); }
});

setTitle();
