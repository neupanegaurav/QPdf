(function(){
  try{ var s=localStorage.getItem('qpdf-theme'); if(s) document.documentElement.setAttribute('data-theme', s); }catch(e){}

  var header = document.getElementById('siteHeader');
  var onScroll = function(){ header.classList.toggle('scrolled', window.scrollY > 12); };
  document.addEventListener('scroll', onScroll, {passive:true}); onScroll();

  var toggle = document.querySelector('.theme-toggle');
  var isDark = document.documentElement.getAttribute('data-theme') === 'dark' ||
    (!document.documentElement.hasAttribute('data-theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
  toggle.setAttribute('aria-pressed', String(isDark));
  toggle.addEventListener('click', function(){
    var cur = document.documentElement.getAttribute('data-theme');
    var mql = window.matchMedia('(prefers-color-scheme: dark)').matches;
    var next;
    if(!cur){ next = mql ? 'light' : 'dark'; } else { next = cur === 'dark' ? 'light' : 'dark'; }
    document.documentElement.setAttribute('data-theme', next);
    try{ localStorage.setItem('qpdf-theme', next); }catch(e){}
    toggle.setAttribute('aria-pressed', String(next === 'dark'));
  });

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var navToggle = document.querySelector('.nav-toggle');
  var mobileNav = document.getElementById('mobileNav');
  function closeMenu(){
    mobileNav.classList.remove('is-open');
    navToggle.setAttribute('aria-expanded', 'false');
    navToggle.setAttribute('aria-label', 'Open menu');
  }
  navToggle.addEventListener('click', function(){
    var open = navToggle.getAttribute('aria-expanded') !== 'true';
    mobileNav.classList.toggle('is-open', open);
    navToggle.setAttribute('aria-expanded', String(open));
    navToggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  });
  mobileNav.querySelectorAll('a').forEach(function(link){ link.addEventListener('click', closeMenu); });
  document.addEventListener('keydown', function(e){ if(e.key === 'Escape') closeMenu(); });

  requestAnimationFrame(function(){ document.querySelector('.hero').classList.add('is-loaded'); });

  if('IntersectionObserver' in window && !reduced){
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(e){
        if(e.isIntersecting){ e.target.classList.add('is-visible'); io.unobserve(e.target); }
      });
    }, {threshold:.14, rootMargin:'0px 0px -6% 0px'});
    document.querySelectorAll('.reveal').forEach(function(el, i){
      el.style.setProperty('--i', i % 6);
      io.observe(el);
    });
  } else {
    document.querySelectorAll('.reveal').forEach(function(el){ el.classList.add('is-visible'); });
  }

  var rail = document.getElementById('rail');
  var dotsWrap = document.getElementById('railDots');
  var cards = rail.querySelectorAll('.rail-card');
  cards.forEach(function(_, i){
    var b = document.createElement('button');
    b.className = 'rail-dot' + (i === 0 ? ' active' : '');
    b.setAttribute('aria-label', 'Go to screen ' + (i+1));
    b.addEventListener('click', function(){ cards[i].scrollIntoView({behavior: reduced ? 'auto' : 'smooth', inline:'start', block:'nearest'}); });
    dotsWrap.appendChild(b);
  });
  var dots = dotsWrap.querySelectorAll('.rail-dot');
  if('IntersectionObserver' in window){
    var railIo = new IntersectionObserver(function(entries){
      entries.forEach(function(e){
        var idx = Array.prototype.indexOf.call(cards, e.target);
        if(e.isIntersecting){ dots.forEach(function(d,i){ d.classList.toggle('active', i===idx); }); }
      });
    }, {root: rail, threshold:.6});
    cards.forEach(function(c){ railIo.observe(c); });
  }

  var activeCard = 0;
  var counter = document.getElementById('railCurrent');
  function goToCard(index){
    activeCard = (index + cards.length) % cards.length;
    cards[activeCard].scrollIntoView({behavior: reduced ? 'auto' : 'smooth', inline:'start', block:'nearest'});
  }
  document.querySelector('[data-rail-prev]').addEventListener('click', function(){ goToCard(activeCard - 1); });
  document.querySelector('[data-rail-next]').addEventListener('click', function(){ goToCard(activeCard + 1); });
  var syncRail = function(){
    var railBox = rail.getBoundingClientRect();
    var nearest = 0, distance = Infinity;
    cards.forEach(function(card, i){ var d = Math.abs(card.getBoundingClientRect().left - railBox.left); if(d < distance){ distance = d; nearest = i; } });
    activeCard = nearest;
    counter.textContent = String(nearest + 1).padStart(2, '0');
    dots.forEach(function(dot, i){ dot.classList.toggle('active', i === nearest); });
  };
  rail.addEventListener('scroll', syncRail, {passive:true});

  if(!reduced && window.matchMedia('(hover:hover) and (pointer:fine)').matches){
    document.querySelectorAll('[data-tilt]').forEach(function(el){
      el.addEventListener('pointermove', function(e){
        var box = el.getBoundingClientRect();
        var rx = ((e.clientY - box.top) / box.height - .5) * -5;
        var ry = ((e.clientX - box.left) / box.width - .5) * 5;
        el.style.transform = 'perspective(1000px) rotateX(' + rx + 'deg) rotateY(' + ry + 'deg)';
      });
      el.addEventListener('pointerleave', function(){ el.style.transform = ''; });
    });
  }

  var yearEl = document.querySelector('[data-year]');
  if(yearEl) yearEl.textContent = new Date().getFullYear();
})();
