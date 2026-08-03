/*
 * Scroll-reveal — cards and post sections fade + rise gently as they enter view.
 * Progressive enhancement done safely:
 *   - Does nothing (content stays visible) if IntersectionObserver is missing,
 *     JS is off, or the visitor prefers reduced motion.
 *   - A 2.5s safety timer force-reveals everything, so content can never get
 *     stuck hidden if an observer callback doesn't fire.
 */
(function () {
  if (!("IntersectionObserver" in window)) return;
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  function run() {
    var root = document.documentElement;
    root.classList.add("js-reveal"); // gates the hidden state in CSS
    var els = document.querySelectorAll(".md-post--excerpt, .za-card");
    if (!els.length) return;

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in-view"); io.unobserve(e.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.05 });

    els.forEach(function (el) { el.classList.add("reveal"); io.observe(el); });

    // Safety net: never leave anything hidden.
    setTimeout(function () {
      document.querySelectorAll(".reveal:not(.in-view)").forEach(function (el) { el.classList.add("in-view"); });
    }, 2500);
  }

  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(run);
  } else if (document.readyState !== "loading") {
    run();
  } else {
    document.addEventListener("DOMContentLoaded", run);
  }
})();
