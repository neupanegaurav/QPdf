/* QPdf site behaviour — no dependencies, no network, no analytics. */
(function () {
  'use strict';

  var root = document.documentElement;
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  root.classList.remove('no-js');

  /* --- Theme toggle ----------------------------------------------------- */

  function systemTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function currentTheme() {
    return root.getAttribute('data-theme') || systemTheme();
  }

  var toggle = document.querySelector('.theme-toggle');
  if (toggle) {
    var sync = function () {
      var dark = currentTheme() === 'dark';
      toggle.setAttribute('aria-pressed', String(dark));
      toggle.setAttribute('aria-label', dark ? 'Switch to light theme' : 'Switch to dark theme');
    };
    sync();
    toggle.addEventListener('click', function () {
      var next = currentTheme() === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem('qpdf-theme', next); } catch (e) { /* private mode */ }
      sync();
    });
  }

  /* --- Sticky header state ---------------------------------------------- */

  var header = document.querySelector('.site-header');
  var progress = document.querySelector('.progress');

  function onScroll() {
    if (header) header.classList.toggle('is-stuck', window.scrollY > 8);
    if (progress) {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      progress.style.transform = 'scaleX(' + (max > 0 ? Math.min(window.scrollY / max, 1) : 0) + ')';
    }
  }

  var ticking = false;
  window.addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () { onScroll(); ticking = false; });
  }, { passive: true });
  onScroll();

  /* --- Scroll reveal ----------------------------------------------------- */

  var revealables = document.querySelectorAll('.reveal');

  if (!('IntersectionObserver' in window) || reduced) {
    Array.prototype.forEach.call(revealables, function (el) { el.classList.add('is-in'); });
  } else {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        observer.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });

    Array.prototype.forEach.call(revealables, function (el) { observer.observe(el); });
  }

  /* Stagger children of any [data-stagger] container. */
  Array.prototype.forEach.call(document.querySelectorAll('[data-stagger]'), function (group) {
    var step = parseInt(group.getAttribute('data-stagger'), 10) || 70;
    Array.prototype.forEach.call(group.children, function (child, i) {
      if (child.classList.contains('reveal')) child.style.setProperty('--d', (i * step) + 'ms');
    });
  });

  /* --- Pointer spotlight on cards ---------------------------------------- */

  if (!reduced && window.matchMedia('(hover: hover)').matches) {
    Array.prototype.forEach.call(document.querySelectorAll('.card'), function (card) {
      card.addEventListener('pointermove', function (event) {
        var box = card.getBoundingClientRect();
        card.style.setProperty('--mx', (event.clientX - box.left) + 'px');
        card.style.setProperty('--my', (event.clientY - box.top) + 'px');
      });
    });
  }

  /* --- Hero parallax ------------------------------------------------------ */

  var stage = document.querySelector('[data-parallax]');
  if (stage && !reduced && window.matchMedia('(hover: hover)').matches) {
    var layers = stage.querySelectorAll('[data-depth]');
    var pending = false;
    var pointer = { x: 0, y: 0 };

    window.addEventListener('pointermove', function (event) {
      pointer.x = (event.clientX / window.innerWidth - 0.5) * 2;
      pointer.y = (event.clientY / window.innerHeight - 0.5) * 2;
      if (pending) return;
      pending = true;
      window.requestAnimationFrame(function () {
        Array.prototype.forEach.call(layers, function (layer) {
          var depth = parseFloat(layer.getAttribute('data-depth')) || 0;
          layer.style.transform =
            'rotate(' + (layer.dataset.tilt || 0) + 'deg) ' +
            'translate3d(' + (pointer.x * depth * -14) + 'px,' + (pointer.y * depth * -10) + 'px,0)';
        });
        pending = false;
      });
    }, { passive: true });
  }

  /* --- Screenshot tabs ----------------------------------------------------- */

  var tablist = document.querySelector('[role="tablist"]');
  if (tablist) {
    var tabs = Array.prototype.slice.call(tablist.querySelectorAll('[role="tab"]'));

    var select = function (tab, focus) {
      tabs.forEach(function (item) {
        var selected = item === tab;
        item.setAttribute('aria-selected', String(selected));
        item.setAttribute('tabindex', selected ? '0' : '-1');
        var panel = document.getElementById(item.getAttribute('aria-controls'));
        if (!panel) return;
        if (selected) panel.setAttribute('data-active', ''); else panel.removeAttribute('data-active');
      });
      if (focus) tab.focus();
    };

    tabs.forEach(function (tab, index) {
      tab.addEventListener('click', function () { select(tab); });
      tab.addEventListener('keydown', function (event) {
        var delta = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
        if (delta) {
          event.preventDefault();
          select(tabs[(index + delta + tabs.length) % tabs.length], true);
        } else if (event.key === 'Home' || event.key === 'End') {
          event.preventDefault();
          select(event.key === 'Home' ? tabs[0] : tabs[tabs.length - 1], true);
        }
      });
    });
  }

  /* --- Table-of-contents scrollspy (policy page) --------------------------- */

  var tocLinks = document.querySelectorAll('.toc a');
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var byId = {};
    var sections = [];

    Array.prototype.forEach.call(tocLinks, function (link) {
      var id = link.getAttribute('href').slice(1);
      var section = document.getElementById(id);
      if (!section) return;
      byId[id] = link;
      sections.push(section);
    });

    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        Array.prototype.forEach.call(tocLinks, function (link) { link.classList.remove('is-current'); });
        var link = byId[entry.target.id];
        if (link) link.classList.add('is-current');
      });
    }, { rootMargin: '-12% 0px -70% 0px', threshold: 0 });

    sections.forEach(function (section) { spy.observe(section); });
  }

  /* --- Year stamp ---------------------------------------------------------- */

  Array.prototype.forEach.call(document.querySelectorAll('[data-year]'), function (el) {
    el.textContent = String(new Date().getFullYear());
  });
})();
