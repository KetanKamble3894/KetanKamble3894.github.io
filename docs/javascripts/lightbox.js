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
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
