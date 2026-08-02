/*
 * Editorial byline for blog posts.
 * Material renders a post's date / reading-time / category into the left
 * sidebar. This clones those items (icon + text) into a single compact row
 * placed directly under the post H1 — the scloud.work-style masthead —
 * without duplicating any data or touching the template. Progressive
 * enhancement: with JS off, the meta still lives in the sidebar.
 */
(function () {
  function buildByline() {
    var content = document.querySelector('.md-content--post .md-content__inner')
      || document.querySelector('.md-content__inner');
    if (!content) return;

    var h1 = content.querySelector('h1');
    if (!h1) return;
    if (content.querySelector('.kk-byline')) return; // idempotent

    // The sidebar meta items: date, (updated), category, readtime.
    var items = document.querySelectorAll(
      '.md-sidebar--post .md-post__meta .md-nav > .md-nav__list .md-nav__link'
    );
    if (!items.length) return;

    var row = document.createElement('div');
    row.className = 'kk-byline';

    Array.prototype.forEach.call(items, function (item) {
      var text = (item.textContent || '').trim();
      if (!text) return;
      var span = document.createElement('span');
      span.className = 'kk-byline__item';
      span.innerHTML = item.innerHTML; // icon + label, already styled upstream
      // Strip any cloned id/for attributes so we don't create duplicate DOM IDs.
      Array.prototype.forEach.call(span.querySelectorAll('[id]'), function (el) {
        el.removeAttribute('id');
      });
      row.appendChild(span);
    });

    if (!row.childNodes.length) return;
    h1.insertAdjacentElement('afterend', row);
  }

  if (window.document$ && typeof window.document$.subscribe === 'function') {
    window.document$.subscribe(buildByline); // Material instant-nav aware
  } else if (document.readyState !== 'loading') {
    buildByline();
  } else {
    document.addEventListener('DOMContentLoaded', buildByline);
  }
})();
