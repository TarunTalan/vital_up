// VitalUp website: theme, navigation, scroll effects. No dependencies.
(function () {
  'use strict';
  var root = document.documentElement;
  root.classList.remove('no-js');

  function store(key, value) {
    try {
      if (value === undefined) return localStorage.getItem(key);
      if (value === null) localStorage.removeItem(key); else localStorage.setItem(key, value);
    } catch (e) { return null; }
  }

  // Theme: follows the system until the visitor picks one.
  function systemDark() { return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches; }
  function currentTheme() { return root.getAttribute('data-theme') || (systemDark() ? 'dark' : 'light'); }
  function syncThemeMeta() {
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', currentTheme() === 'dark' ? '#141414' : '#F6F8F9');
    document.querySelectorAll('.theme-toggle').forEach(function (b) {
      b.setAttribute('aria-label', currentTheme() === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
    });
  }
  document.querySelectorAll('.theme-toggle').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var next = currentTheme() === 'dark' ? 'light' : 'dark';
      if ((next === 'dark') === systemDark()) {
        root.removeAttribute('data-theme');
        store('vitalup-theme', null);
      } else {
        root.setAttribute('data-theme', next);
        store('vitalup-theme', next);
      }
      syncThemeMeta();
    });
  });
  syncThemeMeta();

  // Header: glass once the page scrolls.
  var header = document.querySelector('.site-header');
  var backTop = document.querySelector('.back-top');
  function onScroll() {
    var y = window.scrollY || 0;
    if (header) header.classList.toggle('scrolled', y > 8);
    if (backTop) backTop.classList.toggle('show', y > 900);
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  if (backTop) backTop.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: 'smooth' }); });

  // Mobile menu.
  var menuBtn = document.querySelector('.menu-btn');
  var menu = document.getElementById('nav-menu');
  function setMenu(open) {
    if (!menu || !menuBtn) return;
    menu.classList.toggle('open', open);
    menuBtn.setAttribute('aria-expanded', String(open));
    menuBtn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    var icon = menuBtn.querySelector('.ic');
    if (icon) icon.className = 'ic ' + (open ? 'ic-close' : 'ic-menu');
    if (header) header.classList.toggle('menu-open', open);
  }
  if (menuBtn && menu) {
    menuBtn.addEventListener('click', function (e) { e.stopPropagation(); setMenu(!menu.classList.contains('open')); });
    menu.addEventListener('click', function (e) { if (e.target.closest('a')) setMenu(false); });
    document.addEventListener('click', function (e) { if (menu.classList.contains('open') && !menu.contains(e.target)) setMenu(false); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') setMenu(false); });
    window.addEventListener('resize', function () { if (window.innerWidth > 900) setMenu(false); });
  }

  // Reveal on scroll.
  var reveals = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { entry.target.classList.add('in'); io.unobserve(entry.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }

  // Table of contents: highlight the section being read.
  var tocLinks = document.querySelectorAll('.toc a[href^="#"]');
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var byId = {};
    tocLinks.forEach(function (a) {
      var id = a.getAttribute('href').slice(1);
      (byId[id] = byId[id] || []).push(a);
    });
    var visible = {};
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) { visible[entry.target.id] = entry.isIntersecting; });
      var first = Object.keys(byId).find(function (id) { return visible[id]; });
      if (!first) return;
      tocLinks.forEach(function (a) { a.classList.remove('active'); });
      byId[first].forEach(function (a) { a.classList.add('active'); });
    }, { rootMargin: '-' + (72 + 16) + 'px 0px -55% 0px' });
    Object.keys(byId).forEach(function (id) { var el = document.getElementById(id); if (el) spy.observe(el); });
    // Close the mobile contents after picking a section.
    document.querySelectorAll('.toc-mobile a').forEach(function (a) {
      a.addEventListener('click', function () { var d = a.closest('details'); if (d) d.open = false; });
    });
  }

  // Screenshot carousel arrows.
  document.querySelectorAll('[data-carousel]').forEach(function (wrap) {
    var track = wrap.querySelector('.gallery-track');
    var prev = wrap.querySelector('[data-dir="-1"]');
    var next = wrap.querySelector('[data-dir="1"]');
    if (!track) return;
    function step() { var item = track.querySelector('.gallery-item'); return item ? item.getBoundingClientRect().width + 20 : 300; }
    function update() {
      var max = track.scrollWidth - track.clientWidth - 4;
      if (prev) prev.disabled = track.scrollLeft <= 4;
      if (next) next.disabled = track.scrollLeft >= max;
    }
    [prev, next].forEach(function (b) {
      if (b) b.addEventListener('click', function () { track.scrollBy({ left: step() * Number(b.dataset.dir), behavior: 'smooth' }); });
    });
    track.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    update();
  });

  document.querySelectorAll('[data-year]').forEach(function (el) { el.textContent = String(new Date().getFullYear()); });
})();
