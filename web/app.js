// Shared render glue for MDness (macOS WKWebView + Linux WebKitGTK).
// Markdown → HTML via markdown-it, then Mermaid diagrams for ```mermaid fences.
// The native shell either bakes the source into #md-source (export path) or
// calls window.mdnessRender(text) directly (live preview).
(function () {
  "use strict";

  var md = window.markdownit({
    html: true,      // allow raw inline HTML, matching common Markdown usage
    linkify: true,   // autolink bare URLs
    typographer: false,
    breaks: false,   // single newlines are not <br>, matching GitHub .md rendering
  });

  // Render ```mermaid fences as <pre class="mermaid"> so Mermaid can pick them
  // up; everything else uses the default fenced-code renderer.
  var defaultFence = md.renderer.rules.fence.bind(md.renderer.rules);
  md.renderer.rules.fence = function (tokens, idx, options, env, self) {
    var info = (tokens[idx].info || "").trim().split(/\s+/g)[0];
    if (info === "mermaid") {
      return '<pre class="mermaid">' + escapeHtml(tokens[idx].content) + "</pre>\n";
    }
    return defaultFence(tokens, idx, options, env, self);
  };

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // GitHub task lists: markdown-it emits "[ ] "/"[x] " as literal text at the
  // start of a list item. Swap those for real (disabled) checkboxes.
  function renderMarkdown(text) {
    return md
      .render(text)
      .replace(/<li>(\s*)\[ \]\s/g, '<li class="task-item">$1<input type="checkbox" disabled> ')
      .replace(/<li>(\s*)\[[xX]\]\s/g, '<li class="task-item">$1<input type="checkbox" checked disabled> ')
      .replace(/<li>(\s*<p>)\[ \]\s/g, '<li class="task-item">$1<input type="checkbox" disabled> ')
      .replace(/<li>(\s*<p>)\[[xX]\]\s/g, '<li class="task-item">$1<input type="checkbox" checked disabled> ');
  }

  function mermaidTheme() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "default";
  }

  var mermaidReady = false;
  function ensureMermaid() {
    if (!mermaidReady && window.mermaid) {
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "strict",
        theme: mermaidTheme(),
      });
      mermaidReady = true;
    }
  }

  // Renders `text` into #content and awaits all Mermaid diagrams, then flips a
  // flag the native exporters poll before printing / capturing the DOM.
  window.mdnessRender = function (text) {
    window.__mdnessRenderComplete = false;
    var article = document.getElementById("content");
    article.innerHTML = renderMarkdown(text || "");

    var diagrams = article.querySelectorAll("pre.mermaid");
    if (!diagrams.length || !window.mermaid) {
      window.__mdnessRenderComplete = true;
      return;
    }
    ensureMermaid();
    window.mermaid
      .run({ nodes: diagrams })
      .catch(function () {
        // Leave any un-rendered diagram as its source text; don't block export.
      })
      .finally(function () {
        window.__mdnessRenderComplete = true;
      });
  };

  // Export path: the source is baked into the page, so render on load.
  function renderFromDOM() {
    var src = document.getElementById("md-source");
    if (src && src.textContent) {
      try {
        window.mdnessRender(JSON.parse(src.textContent));
        return;
      } catch (e) { /* fall through */ }
    }
    window.__mdnessRenderComplete = true;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", renderFromDOM);
  } else {
    renderFromDOM();
  }
})();
