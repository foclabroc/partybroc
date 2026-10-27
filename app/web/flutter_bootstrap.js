{{flutter_js}}
{{flutter_build_config}}

// Démarrage de PartyBroc : CanvasKit est servi par notre serveur (pas de CDN),
// pas de service worker (il garde parfois une vieille version en cache).
(function () {
  const status = document.getElementById('pb-status');
  const show = (html) => { if (status) { status.innerHTML = html; status.style.display = 'block'; } };
  const fail = (why) => show(
    '<b>PartyBroc n’arrive pas à démarrer sur ce navigateur.</b><br>' + why +
    '<br><br><small>' + navigator.userAgent + '</small>');

  // Indispensable : WebAssembly
  if (typeof WebAssembly !== 'object') return fail('WebAssembly n’est pas disponible.');

  // WebGL : souvent coupé sur les navigateurs de TV. Sans lui, on dessine
  // en mode logiciel (CanvasKit sur le processeur) : plus lent mais ça marche.
  let webgl = false;
  try {
    const c = document.createElement('canvas');
    webgl = !!(c.getContext('webgl2') || c.getContext('webgl'));
  } catch (e) { webgl = false; }
  const config = webgl ? {} : { renderer: 'canvaskit', canvasKitForceCpuOnly: true };
  if (!webgl) console.warn('PartyBroc : pas de WebGL, rendu logiciel');

  const slow = setTimeout(() => fail('Le chargement prend trop de temps (plus de 30 s).'), 30000);
  window.addEventListener('flutter-first-frame', () => {
    clearTimeout(slow);
    const l = document.getElementById('pb-loading');
    if (l) l.remove();
  });

  _flutter.loader.load({
    config: config,
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const app = await engineInitializer.initializeEngine();
        await app.runApp();
      } catch (e) {
        clearTimeout(slow);
        fail('Erreur au démarrage : ' + (e && e.message ? e.message : e));
      }
    },
  }).catch(function (e) {
    clearTimeout(slow);
    fail('Erreur au chargement : ' + (e && e.message ? e.message : e));
  });
})();
