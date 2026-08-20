// Lightweight, accessible click-to-zoom for content images (Power BI reports,
// diagrams, portal screenshots). No dependencies. Click image to open full-size;
// click backdrop, press the × button, or hit Esc to close. Focus is moved to the
// close button on open and restored on close.
(function () {
  function init() {
    var imgs = document.querySelectorAll('.md-content img');
    if (!imgs.length) return;

    var overlay = document.createElement('div');
    overlay.className = 'kk-lightbox';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Image preview');
    overlay.setAttribute('aria-hidden', 'true');

    var big = document.createElement('img');
    big.alt = '';

    var closeBtn = document.createElement('button');
    closeBtn.className = 'kk-lightbox__close';
    closeBtn.setAttribute('type', 'button');
    closeBtn.setAttribute('aria-label', 'Close image preview');
    closeBtn.innerHTML = '&times;';

    overlay.appendChild(big);
    overlay.appendChild(closeBtn);
    document.body.appendChild(overlay);

    var lastFocus = null;

    function open(src, alt, trigger) {
      lastFocus = trigger || document.activeElement;
      big.src = src;
      big.alt = alt || '';
      overlay.classList.add('open');
      overlay.setAttribute('aria-hidden', 'false');
      closeBtn.focus();
    }
    function close() {
      overlay.classList.remove('open');
      overlay.setAttribute('aria-hidden', 'true');
      big.src = '';
      if (lastFocus && lastFocus.focus) lastFocus.focus();
    }

    overlay.addEventListener('click', function (e) {
      if (e.target !== big) close(); // click backdrop or the × closes; clicking the image itself doesn't
    });
    closeBtn.addEventListener('click', close);
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && overlay.classList.contains('open')) close();
    });

    imgs.forEach(function (im) {
      im.style.cursor = 'zoom-in';
      im.setAttribute('tabindex', '0');
      im.setAttribute('role', 'button');
      function trigger() {
        var natural = im.naturalWidth || 0;
        if (natural && natural < 240) return; // too small to be worth zooming (icons/avatars)
        open(im.currentSrc || im.src, im.alt, im);
      }
      im.addEventListener('click', trigger);
      im.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); trigger(); }
      });
    });

    // Inline diagram SVGs (mermaid --8<-- includes) are <svg>, not <img>, so the
    // loop above skips them. Wire the diagram container up for click/Enter zoom too,
    // serializing the live SVG to a data URL on first open.
    var diagrams = document.querySelectorAll('.md-content .mermaid-live svg, .md-content .mermaid svg');
    Array.prototype.forEach.call(diagrams, function (svg) {
      var wrap = svg.closest('.mermaid-live, .mermaid') || svg;
      if (wrap.getAttribute('data-zoomable') === '1') return; // guard against double-wiring
      wrap.setAttribute('data-zoomable', '1');
      wrap.style.cursor = 'zoom-in';
      wrap.setAttribute('tabindex', '0');
      wrap.setAttribute('role', 'button');
      wrap.setAttribute('aria-label', 'Zoom diagram to full size');
      var cached = null;
      function toURL() {
        if (cached) return cached;
        var clone = svg.cloneNode(true);
        if (!clone.getAttribute('xmlns')) clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
        // A standalone SVG needs concrete pixel dimensions to render at full size —
        // width="100%" collapses to nothing outside its flow container.
        var vb = (clone.getAttribute('viewBox') || '0 0 1200 630').split(/[\s,]+/);
        var w = Math.round(parseFloat(vb[2]) || 1200), h = Math.round(parseFloat(vb[3]) || 630);
        clone.setAttribute('width', w);
        clone.setAttribute('height', h);
        // Dark rounded padding so the light-on-transparent diagram stays legible when zoomed.
        clone.style.background = '#0B1220';
        clone.style.padding = '24px';
        clone.style.borderRadius = '12px';
        var s = new XMLSerializer().serializeToString(clone);
        cached = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s);
        return cached;
      }
      function trigger() { open(toURL(), 'Diagram, full size', wrap); }
      wrap.addEventListener('click', trigger);
      wrap.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); trigger(); }
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
