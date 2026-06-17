/* ============ Eatstreak interactions ============ */
(function () {
  'use strict';
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- Scroll progress + nav state ---- */
  const progress = document.getElementById('scrollProgress');
  const nav = document.getElementById('nav');
  function onScroll() {
    const h = document.documentElement;
    const scrolled = h.scrollTop / (h.scrollHeight - h.clientHeight);
    progress.style.width = (scrolled * 100) + '%';
    nav.classList.toggle('scrolled', h.scrollTop > 40);
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---- Reveal on scroll ---- */
  const revealEls = document.querySelectorAll('[data-reveal]');
  const revealIO = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        e.target.classList.add('in');
        revealIO.unobserve(e.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
  revealEls.forEach((el) => revealIO.observe(el));

  /* ---- Animated counters ---- */
  function animateCount(el) {
    const target = parseFloat(el.dataset.count);
    const decimals = parseInt(el.dataset.decimals || '0', 10);
    const suffix = el.dataset.suffix || '';
    const prefix = el.dataset.prefix || '';
    const dur = 1500;
    const start = performance.now();
    function tick(now) {
      const p = Math.min((now - start) / dur, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      const val = (target * eased).toFixed(decimals);
      el.textContent = prefix + val + suffix;
      if (p < 1) requestAnimationFrame(tick);
      else el.textContent = prefix + target.toFixed(decimals) + suffix;
    }
    requestAnimationFrame(tick);
  }
  const counters = document.querySelectorAll('[data-count]:not([data-app-count])');
  const countIO = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        animateCount(e.target);
        countIO.unobserve(e.target);
      }
    });
  }, { threshold: 0.6 });
  counters.forEach((el) => countIO.observe(el));

  /* ---- "in-view" trigger for charts / bars / streak bar ---- */
  const viewTargets = document.querySelectorAll('.streak-card, .ladder, #profitBars, .line-chart, .dash-spark');
  const inViewIO = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) e.target.classList.add('in-view');
    });
  }, { threshold: 0.25 });
  viewTargets.forEach((el) => inViewIO.observe(el));
  // ladder needs .in on each row container
  const ladder = document.querySelector('.ladder');
  if (ladder) {
    new IntersectionObserver((entries) => {
      entries.forEach((e) => { if (e.isIntersecting) ladder.classList.add('in'); });
    }, { threshold: 0.3 }).observe(ladder);
  }

  /* ---- Hero phone subtle parallax tilt ---- */
  const heroPhone = document.getElementById('heroPhone');
  if (heroPhone && !prefersReduced) {
    const hero = document.getElementById('hero');
    hero.addEventListener('mousemove', (ev) => {
      const r = hero.getBoundingClientRect();
      const x = (ev.clientX - r.left) / r.width - 0.5;
      const y = (ev.clientY - r.top) / r.height - 0.5;
      heroPhone.style.transform = `rotateY(${x * 10}deg) rotateX(${-y * 10}deg) translateZ(0)`;
    });
    hero.addEventListener('mouseleave', () => { heroPhone.style.transform = ''; });
  }

  /* ---- Ambient blob parallax on scroll ---- */
  const blobs = document.querySelectorAll('.ambient-blob');
  if (!prefersReduced) {
    let ticking = false;
    window.addEventListener('scroll', () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const y = window.scrollY;
        blobs.forEach((b, i) => {
          const speed = (i + 1) * 0.06;
          b.style.transform = `translateY(${y * speed}px)`;
        });
        ticking = false;
      });
    }, { passive: true });
  }

  /* ---- App showcase scrollytelling ---- */
  const scSteps = document.querySelectorAll('.sc-step');
  const screens = document.querySelectorAll('#showcasePhone .screen');
  function setScreen(idx) {
    screens.forEach((s) => s.classList.toggle('screen-active', +s.dataset.screen === idx));
    scSteps.forEach((s) => s.classList.toggle('active', +s.dataset.sc === idx));
  }
  if (scSteps.length) {
    const scIO = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) setScreen(+e.target.dataset.sc);
      });
    }, { threshold: 0.55 });
    scSteps.forEach((s) => scIO.observe(s));
  }

  /* ---- Waitlist form ---- */
  const segBtns = document.querySelectorAll('.seg-btn');
  segBtns.forEach((b) => b.addEventListener('click', () => {
    segBtns.forEach((x) => x.classList.remove('active'));
    b.classList.add('active');
  }));
  const form = document.getElementById('waitlistForm');
  const success = document.getElementById('formSuccess');
  if (form) {
    form.addEventListener('submit', (ev) => {
      ev.preventDefault();
      const role = document.querySelector('.seg-btn.active')?.dataset.role || 'diner';
      success.textContent = role === 'restaurant'
        ? "You're on the list 🔥 — we'll reach out to set up your free pilot."
        : "You're on the list 🔥 — founding-member perks are yours at launch.";
      success.classList.add('show');
      form.querySelector('input[type=email]').value = '';
    });
  }
})();
