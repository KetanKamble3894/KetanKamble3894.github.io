/* Vendored Mermaid init — brand-themed, fully self-contained (no external CDN).
   Renders <pre class="mermaid-src"><code>…</code></pre> blocks (custom class so
   Material's own CDN-loading mermaid integration stays out of the way). */
(function () {
  function brandVars() {
    return {
      background: "transparent",
      primaryColor: "#141e32",
      primaryTextColor: "#e2e8f0",
      primaryBorderColor: "#2dd4bf",
      lineColor: "#64748b",
      textColor: "#334155",
      actorBkg: "#0b1120",
      actorBorder: "#2dd4bf",
      actorTextColor: "#e2e8f0",
      actorLineColor: "#64748b",
      signalColor: "#475569",
      signalTextColor: "#334155",
      labelBoxBkgColor: "#0b1120",
      labelBoxBorderColor: "#2dd4bf",
      labelTextColor: "#e2e8f0",
      loopTextColor: "#334155",
      noteBkgColor: "#0b1120",
      noteTextColor: "#5eead4",
      noteBorderColor: "#2dd4bf",
      sequenceNumberColor: "#0b1120",
      activationBkgColor: "#2dd4bf"
    };
  }

  function render() {
    if (!window.mermaid) return;
    window.mermaid.initialize({
      startOnLoad: false,
      theme: "base",
      fontFamily: '"Inter", system-ui, -apple-system, sans-serif',
      themeVariables: brandVars(),
      sequence: { actorMargin: 46, mirrorActors: true, noteMargin: 12, messageMargin: 34, useMaxWidth: true },
      flowchart: { useMaxWidth: true, htmlLabels: true },
      securityLevel: "loose"
    });
    var blocks = document.querySelectorAll("pre.mermaid-src");
    blocks.forEach(function (el) {
      var code = el.querySelector("code");
      var src = code ? code.textContent : el.textContent;
      var div = document.createElement("div");
      div.className = "mermaid-live";
      div.textContent = src;
      el.replaceWith(div);
    });
    try {
      window.mermaid.run({ querySelector: ".mermaid-live" });
    } catch (e) { /* no-op */ }
  }

  if (document.readyState !== "loading") { render(); }
  else { document.addEventListener("DOMContentLoaded", render); }
})();
