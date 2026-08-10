(function(){
  try{ var s=localStorage.getItem('qpdf-theme'); if(s) document.documentElement.setAttribute('data-theme', s); }catch(e){}

  var header = document.getElementById('siteHeader');
  var onScroll = function(){ header.classList.toggle('scrolled', window.scrollY > 12); };
  document.addEventListener('scroll', onScroll, {passive:true}); onScroll();

  var toggle = document.querySelector('.theme-toggle');
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

  requestAnimationFrame(function(){ document.querySelector('.hero').classList.add('is-loaded'); });

  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(e){
      if(e.isIntersecting){ e.target.classList.add('is-visible'); io.unobserve(e.target); }
    });
  }, {threshold:.14, rootMargin:'0px 0px -6% 0px'});
  document.querySelectorAll('.reveal').forEach(function(el, i){
    el.style.setProperty('--i', i % 6);
    io.observe(el);
  });

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
  var railIo = new IntersectionObserver(function(entries){
    entries.forEach(function(e){
      var idx = Array.prototype.indexOf.call(cards, e.target);
      if(e.isIntersecting){ dots.forEach(function(d,i){ d.classList.toggle('active', i===idx); }); }
    });
  }, {root: rail, threshold:.6});
  cards.forEach(function(c){ railIo.observe(c); });

  var yearEl = document.querySelector('[data-year]');
  if(yearEl) yearEl.textContent = new Date().getFullYear();
})();
